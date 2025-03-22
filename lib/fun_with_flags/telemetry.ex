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

  @doc false
  @spec persistence_event(atom, :telemetry.event_metadata()) :: :ok
  def persistence_event(event_name, metadata) do
    measurements = %{
      system_time: :erlang.system_time()
    }

    Logger.debug(fn ->
      "Telemetry event: #{inspect(event_name)}, metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    end)

    :telemetry.execute([:fun_with_flags, :persistence, event_name], measurements, metadata)
  end

  # @spec as_milliseconds(integer) :: integer
  # defp as_milliseconds(time) do
  #   :erlang.convert_time_unit(time, :native, :millisecond)
  # end
end
