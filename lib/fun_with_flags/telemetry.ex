defmodule FunWithFlags.Telemetry do
  @moduledoc """
  Telemetry events for FunWithFlags.

  This module centralizes the emission of all [Telemetry](https://hexdocs.pm/telemetry/readme.html)
  events for the package.

  ## Events

  The common prefix for all events is `:fun_with_flags`, followed by a logical
  scope (e.g. `:persistence`) and the event name.

  Events are simple "point in time" events rather than span events (that is,
  there is no distinct `:start` and `:stop` events with a duration measurement).

  ### Persistence

  Events for CRUD operations on the persistent datastore.

  All events contain the same measurement:
  * `system_time` (integer), which is the current system time in the
    `:native` time unit. See `:erlang.system_time/0`.

  Events:

  * `[:fun_with_flags, :persistence, :read]`, emitted when a flag is read from
    the DB. Crucially, this event is not emitted when the cache is enabled and
    there is a cache hit, and it's emitted only when retrieving a flag reads
    from the persistent datastore. Therefore, when the cache is disabled, this
    event is always emitted every time a flag is queried.

    Metadata:
    * `flag_name` (atom), the name of the flag being read.

  * `[:fun_with_flags, :persistence, :read_all_flags]`, emitted when all flags
    are read from the DB. No extra metadata.

  * `[:fun_with_flags, :persistence, :read_all_flag_names]`, emitted when all
    flags names are read from the DB. No extra metadata.

  * `[:fun_with_flags, :persistence, :write]`, emitted when writing a flag to
    the DB. In practive, what is written is one of the gates of the flag, which
    is always upserted.

    Metadata:
    * `flag_name` (atom), the name of the flag being written.
    * `gate` (`FunWithFlags.Gate`), the gate being upserted.

  * `[:fun_with_flags, :persistence, :delete_flag]`, emitted when an entire flag
    is deleted from the DB.

    Metadata:
    * `flag_name` (atom), the name of the flag being deleted.

  * `[:fun_with_flags, :persistence, :delete_gate]`, emitted when one of the flag's
    gates is deleted from the DB.

    Metadata:
    * `flag_name` (atom), the name of the flag whose gate is being deleted.
    * `gate` (`FunWithFlags.Gate`), the gate being deleted.

  * `[:fun_with_flags, :persistence, :reload]`, emitted when a flag is reloaded
    from the DB. This typically happens when the node has received a change
    notification for a flag, which results in the cache being invalidated and
    the flag being reloaded from the DB.

    Metadata:
    * `flag_name` (atom), the name of the flag being reloaded.

  * `[:fun_with_flags, :persistence, :error]`, emitted for erorrs in any of the
    above operations.

    Metadata:
    * `error` (any), the error that occurred. This is typically a string or any
      appropriate error term returned by the underlying persistence adapters.
    * `original_event` (atom), the name of the original event that failed, e.g.
      `:read`, `:write`, `:delete_gate`, etc.
    * `flag_name` (atom), the name of the flag being operated on, if supported
      by the original event.
    * `gate` (`FunWithFlags.Gate`), the gate being operated on, if supported by
      the original event.
  """

  require Logger

  @typedoc false
  @type pipelining_value :: {:ok, any()} | {:error, any()}

  # Receive the flag name as an explicit parameter rather than pattern matching
  # it from the `{:ok, _}` tuple, because:
  #
  # * That tuple is only available on success, and it's therefore not available
  #   when pipelining on an error.
  # * It makes it possible to use this function even when the :ok result does
  #   not contain a flag.
  #
  @doc false
  @spec emit_persistence_event(
    pipelining_value(),
    event_name :: atom(),
    flag_name :: (atom() | nil),
    gate :: (FunWithFlags.Gate.t | nil)
  ) :: pipelining_value()
  def emit_persistence_event(result = {:ok, _}, event_name, flag_name, gate) do
    metadata = %{
      flag_name: flag_name,
      gate: gate,
    }

    do_send_event([:fun_with_flags, :persistence, event_name], metadata)
    result
  end

  def emit_persistence_event(result = {:error, reason}, event_name, flag_name, gate) do
    metadata = %{
      flag_name: flag_name,
      gate: gate,
      error: reason,
      original_event: event_name
    }

    do_send_event([:fun_with_flags, :persistence, :error], metadata)
    result
  end

  @doc false
  @spec do_send_event([atom], :telemetry.event_metadata()) :: :ok
  def do_send_event(event_name, metadata) do
    measurements = %{
      system_time: :erlang.system_time()
    }

    Logger.debug(fn ->
      "Telemetry event: #{inspect(event_name)}, metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    end)

    :telemetry.execute(event_name, measurements, metadata)
  end


  @doc """
  Attach a debug handler to FunWithFlags telemetry events.

  Attach a Telemetry handler that logs all events at the `:alert` level.
  It uses the `:alert` level rather than `:debug` or `:info` simply to make it
  more convenient to eyeball these logs and to print them while running the tests.
  """
  @spec attach_debug_handler() :: :ok | {:error, :already_exists}
  def attach_debug_handler do
    events = [
      [:fun_with_flags, :persistence, :read],
      [:fun_with_flags, :persistence, :read_all_flags],
      [:fun_with_flags, :persistence, :read_all_flag_names],
      [:fun_with_flags, :persistence, :write],
      [:fun_with_flags, :persistence, :delete_flag],
      [:fun_with_flags, :persistence, :delete_gate],
      [:fun_with_flags, :persistence, :reload],
      [:fun_with_flags, :persistence, :error],
    ]

    :telemetry.attach_many("local-debug-handler", events, &__MODULE__.debug_event_handler/4, %{})
  end

  @doc false
  def debug_event_handler([:fun_with_flags, :persistence, event], %{system_time: system_time}, metadata, _config) do
    dt = DateTime.from_unix!(system_time, :native) |> DateTime.to_iso8601()

    Logger.alert(fn ->
      "FunWithFlags telemetry event: #{event}, system_time: #{dt}, metadata: #{inspect(metadata)}"
    end)

    :ok
  end
end
