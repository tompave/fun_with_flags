defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  import FunWithFlags.Config, only: [persistence_adapter: 0]
  alias FunWithFlags.Telemetry

  @spec lookup(atom) :: {:ok, FunWithFlags.Flag.t}
  def lookup(flag_name) do
    result =
      persistence_adapter().get(flag_name)
      |> Telemetry.emit_persistence_event(:read, flag_name, nil)

    case result do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  @spec put(atom, FunWithFlags.Gate.t) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def put(flag_name, gate) do
    persistence_adapter().put(flag_name, gate)
    |> Telemetry.emit_persistence_event(:write, flag_name, gate)
  end

  @spec delete(atom, FunWithFlags.Gate.t) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name, gate) do
    persistence_adapter().delete(flag_name, gate)
    |> Telemetry.emit_persistence_event(:delete_gate, flag_name, gate)
  end

  @spec delete(atom) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name) do
    persistence_adapter().delete(flag_name)
    |> Telemetry.emit_persistence_event(:delete_flag, flag_name, nil)
  end

  @spec all_flags() :: {:ok, [FunWithFlags.Flag.t]} | {:error, any()}
  def all_flags do
    persistence_adapter().all_flags()
    |> Telemetry.emit_persistence_event(:read_all_flags, nil, nil)
  end

  @spec all_flag_names() :: {:ok, [atom]} | {:error, any()}
  def all_flag_names do
    persistence_adapter().all_flag_names()
    |> Telemetry.emit_persistence_event(:read_all_flag_names, nil, nil)
  end
end
