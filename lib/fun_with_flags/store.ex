defmodule FunWithFlags.Store do
  alias FunWithFlags.Store.Cache

  def lookup(flag_name) do
    Cache.get(flag_name)
  end

  def put(flag_name, value) do
    Cache.put(flag_name, value)
  end  
end
