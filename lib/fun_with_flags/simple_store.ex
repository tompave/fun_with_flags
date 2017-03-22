defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  alias FunWithFlags.Store.Persistent


  def lookup(flag_name) do
    case Persistent.get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  defdelegate put(flag_name, gate), to: Persistent
  defdelegate delete(flag_name, gate), to: Persistent
  defdelegate delete(flag_name), to: Persistent
end
