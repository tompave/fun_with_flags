defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  alias FunWithFlags.Store.Persistent


  def lookup(flag_name) do
    case Persistent.get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      error -> error
    end
  end


  def put(flag_name, gate) do
    Persistent.put(flag_name, gate)
  end
end
