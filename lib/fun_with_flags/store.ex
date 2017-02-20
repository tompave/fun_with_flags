defmodule FunWithFlags.Store do
  @moduledoc false

  alias FunWithFlags.Store.{Cache, Persistent}


  def lookup(flag_name) do
    case Cache.get(flag_name) do
      {:miss, reason, stale_value_or_nil} ->
        case Persistent.get(flag_name) do
          {:error, _reason} ->
            try_to_use_the_cached_value(reason, stale_value_or_nil)
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


  defp try_to_use_the_cached_value(:not_found, nil), do: false
  defp try_to_use_the_cached_value(:expired, value), do: value


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
