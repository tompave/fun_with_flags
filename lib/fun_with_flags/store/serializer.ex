defmodule FunWithFlags.Store.Serializer do
  @moduledoc false
  alias FunWithFlags.Gate

  @type redis_hash_pair :: [String.t]
  
  @spec to_redis(FunWithFlags::Gate.t) :: redis_hash_pair

  def to_redis(%Gate{type: :boolean, for: nil, enabled: enabled}) do
    ["boolean", to_string(enabled)]
  end

  # def to_redis(%Gate{type: type, for: for, enabled: enabled}) do
  #   [serialize(type, for), enabled]
  # end
  # defp serialize(type, for), do: "#{type}/#{for}"
end
