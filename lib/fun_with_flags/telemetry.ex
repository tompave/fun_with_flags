defmodule FunWithFlags.Telemetry do
  @moduledoc """
  Telemetry events for FunWithFlags.

  This module is responsible for emitting [Telemetry](https://hex.pm/packages/telemetry) events for FunWithFlags.

  ## Events


  ### Persistence

  * `[:fun_with_flags, :persistence, :read]`
  * `[:fun_with_flags, :persistence, :read_all_flags]`
  * `[:fun_with_flags, :persistence, :read_all_flag_names]`
  * `[:fun_with_flags, :persistence, :write]`
  * `[:fun_with_flags, :persistence, :delete_flag]`
  * `[:fun_with_flags, :persistence, :delete_gate]`
  * `[:fun_with_flags, :persistence, :reload]`
  * `[:fun_with_flags, :persistence, :error]`

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
end
