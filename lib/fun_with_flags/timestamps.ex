defmodule FunWithFlags.Timestamps do
  @moduledoc false

  def now do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  def expired?(timestamp, ttl, flutter_offset \\ 0) do
    n = __MODULE__.now()
    IO.inspect(timestamp)
    IO.inspect(ttl)
    IO.inspect(flutter_offset)
    IO.inspect((timestamp) - n)
    IO.puts("---------")

    (timestamp + ttl + flutter_offset) < n
  end
end
