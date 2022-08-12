if Code.ensure_loaded?(Ecto.Adapters.SQL) do

defmodule FunWithFlags.Store.Serializer.Ecto do
  @moduledoc false

  alias FunWithFlags.Flag
  alias FunWithFlags.Gate
  alias FunWithFlags.Store.Persistent.Ecto.Record

  def deserialize_flag(name, []), do: Flag.new(to_atom(name), [])

  def deserialize_flag(name, list) when is_list(list) do
    gates =
      list
      |> Enum.sort_by(&(&1.gate_type))
      |> Enum.map(&deserialize_gate(to_string(name), &1))
      |> Enum.reject(&(!&1))
    Flag.new(to_atom(name), gates)
  end


  def deserialize_gate(flag_name, record = %Record{flag_name: flag_name}) do
    do_deserialize_gate(record)
  end

  def deserialize_gate(_flag_name, _record), do: nil


  defp do_deserialize_gate(%Record{gate_type: "boolean", enabled: enabled}) do
    %Gate{type: :boolean, for: nil, enabled: enabled}
  end

  defp do_deserialize_gate(%Record{gate_type: "actor", enabled: enabled, target: target}) do
    %Gate{type: :actor, for: target, enabled: enabled}
  end

  defp do_deserialize_gate(%Record{gate_type: "group", enabled: enabled, target: target}) do
    %Gate{type: :group, for: target, enabled: enabled}
  end

  defp do_deserialize_gate(%Record{gate_type: "percentage", target: "time/" <> ratio_s}) do
    %Gate{type: :percentage_of_time, for: parse_float(ratio_s), enabled: true}
  end

  defp do_deserialize_gate(%Record{gate_type: "percentage", target: "actors/" <> ratio_s}) do
    %Gate{type: :percentage_of_actors, for: parse_float(ratio_s), enabled: true}
  end

  def to_atom(atm) when is_atom(atm), do: atm
  def to_atom(str) when is_binary(str), do: String.to_atom(str)

  defp parse_float(f_s), do: String.to_float(f_s)
end

end # Code.ensure_loaded?
