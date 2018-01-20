defmodule FunWithFlags.Timestamps do
  @moduledoc false

  def now do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  def expired?(timestamp, ttl) do
    timestamp + ttl < __MODULE__.now()
  end
end
