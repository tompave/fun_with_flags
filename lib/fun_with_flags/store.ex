defmodule FunWithFlags.Store do
  @moduledoc false
  alias FunWithFlags.Store.{Cache, Persistent}

  def lookup(flag_name) do
    case Cache.get(flag_name) do
      :not_found ->
        bool = Persistent.get(flag_name)
        {:ok, ^bool} = Cache.put(flag_name, bool)
        bool
      {:found, value} ->
        value
    end
  end

  def put(flag_name, value) do
    Persistent.put(flag_name, value)
    Cache.put(flag_name, value)
  end  
end
