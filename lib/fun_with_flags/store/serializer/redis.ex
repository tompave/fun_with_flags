defmodule FunWithFlags.Store.Serializer.Redis do
  @moduledoc false
  alias FunWithFlags.Gate
  alias FunWithFlags.Flag

  @type redis_hash_pair :: [String.t()]

  @spec serialize(FunWithFlags.Gate.t()) :: redis_hash_pair

  def serialize(%Gate{type: :boolean, for: nil, enabled: enabled}) do
    ["boolean", to_string(enabled)]
  end

  def serialize(%Gate{type: :actor, for: actor_id, enabled: enabled}) do
    ["actor/#{actor_id}", to_string(enabled)]
  end

  def serialize(%Gate{type: :group, for: group, enabled: enabled}) do
    ["group/#{group}", to_string(enabled)]
  end

  def serialize(%Gate{type: :percentage_of_time, for: ratio}) do
    ["percentage", "time/#{to_string(ratio)}"]
  end

  def serialize(%Gate{type: :percentage_of_actors, for: ratio}) do
    ["percentage", "actors/#{to_string(ratio)}"]
  end

  def deserialize_gate(["boolean", enabled]) do
    %Gate{type: :boolean, for: nil, enabled: parse_bool(enabled)}
  end

  def deserialize_gate(["actor/" <> actor_id, enabled]) do
    %Gate{type: :actor, for: actor_id, enabled: parse_bool(enabled)}
  end

  def deserialize_gate(["group/" <> group_name, enabled]) do
    %Gate{type: :group, for: group_name, enabled: parse_bool(enabled)}
  end

  def deserialize_gate(["percentage", "time/" <> ratio_s]) do
    %Gate{type: :percentage_of_time, for: parse_float(ratio_s), enabled: true}
  end

  def deserialize_gate(["percentage", "actors/" <> ratio_s]) do
    %Gate{type: :percentage_of_actors, for: parse_float(ratio_s), enabled: true}
  end

  # `list` comes from redis HGETALL, and it would
  # be something like this:
  #
  # [
  #   "boolean",
  #   "true",
  #   "actor/user:42",
  #   "false",
  #   "group/bananas",
  #   "true",
  #   "percentage_of_time",
  #   "0.5"
  # ]
  #
  def deserialize_flag(name, []), do: Flag.new(name, [])

  def deserialize_flag(name, list) when is_list(list) do
    gates =
      list
      |> Enum.chunk_every(2)
      |> Enum.map(&deserialize_gate/1)

    Flag.new(name, gates)
  end

  defp parse_bool("true"), do: true
  defp parse_bool(_), do: false

  defp parse_float(f_s), do: String.to_float(f_s)
end
