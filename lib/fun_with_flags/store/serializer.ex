defmodule FunWithFlags.Store.Serializer do
  @moduledoc false
  alias FunWithFlags.Gate

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
end
