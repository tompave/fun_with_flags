if Code.ensure_loaded?(Ecto) do

defmodule FunWithFlags.Store.Serializer.Ecto do
  @moduledoc false

  alias FunWithFlags.Gate
  alias FunWithFlags.Flag
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


  def deserialize_gate(flag_name, %Record{flag_name: flag_name} = record) do
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

  defp do_deserialize_gate(%Record{gate_type: "percent_of_time", target: ratio}) do
    %Gate{type: :percent_of_time, for: ratio, enabled: true}
  end

  def to_atom(atm) when is_atom(atm), do: atm
  def to_atom(str) when is_binary(str), do: String.to_atom(str)
end

end # Code.ensure_loaded?
