defmodule FunWithFlags.Timestamps do
  def now do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  def expired?(timestamp, ttl) do
    (timestamp + ttl) < now()
  end
end
