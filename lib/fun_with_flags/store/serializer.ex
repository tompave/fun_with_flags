defmodule FunWithFlags.Store.Serializer do
  @moduledoc false
  alias FunWithFlags.Gate
  alias FunWithFlags.Flag

  @type redis_hash_pair :: [String.t]

  @spec to_redis(FunWithFlags::Gate.t) :: redis_hash_pair

  def to_redis(%Gate{type: :boolean, for: nil, enabled: enabled}) do
    ["boolean", to_string(enabled)]
  end

  def to_redis(%Gate{type: :actor, for: actor_id, enabled: enabled}) do
    ["actor/#{actor_id}", to_string(enabled)]
  end

  def to_redis(%Gate{type: :group, for: group, enabled: enabled}) do
    ["group/#{group}", to_string(enabled)]
  end


  def gate_from_redis(["boolean", enabled]) do
    %Gate{type: :boolean, for: nil, enabled: parse_bool(enabled)}
  end

  def gate_from_redis(["actor/" <> actor_id, enabled]) do
    %Gate{type: :actor, for: actor_id, enabled: parse_bool(enabled)}
  end

  def gate_from_redis(["group/" <> group_name, enabled]) do
    %Gate{type: :group, for: String.to_atom(group_name), enabled: parse_bool(enabled)}
  end

  def flag_from_redis(name, []), do: Flag.new(name, [])
  def flag_from_redis(name, list) when is_list(list) do
    gates =
      list
      |> Enum.chunk(2)
      |> Enum.map(&__MODULE__.gate_from_redis/1)
    Flag.new(name, gates)
  end

  defp parse_bool("true"), do: true
  defp parse_bool(_), do: false
end
