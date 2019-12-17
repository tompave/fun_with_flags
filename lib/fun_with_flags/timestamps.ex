defmodule FunWithFlags.Timestamps do
  @moduledoc false

  def now do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  def expired?(timestamp, ttl, flutter_offset \\ 0) do
    (timestamp + ttl + flutter_offset) < __MODULE__.now()
  end
end
