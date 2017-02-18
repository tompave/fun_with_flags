defmodule FunWithFlags.Store do
  @moduledoc false

  alias FunWithFlags.Store.{Cache, Persistent}


  def lookup(flag_name) do
    case Cache.get(flag_name) do
      {:miss, _reason} ->
        case Persistent.get(flag_name) do
          {:error, _reason} ->
            false
          bool when is_boolean(bool) ->
            # {:ok, ^bool} = Cache.put(flag_name, bool)
            # swallow cache errors for the moment
            Cache.put(flag_name, bool) 
            bool
        end
      {:ok, value} ->
        value
    end
  end


  def put(flag_name, value) do
    case Persistent.put(flag_name, value) do
      {:ok, ^value} ->
        Cache.put(flag_name, value)
      {:error, _reason} = error ->
        error
    end
  end


  def reload(flag_name) do
    # IO.puts "reloading #{flag_name}"
    case Persistent.get(flag_name) do
      {:error, _reason} = error ->
        error
      bool when is_boolean(bool) ->
        Cache.put(flag_name, bool) 
        {:ok, bool}
    end
  end
end
