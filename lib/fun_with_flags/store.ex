defmodule FunWithFlags.Store do
  @moduledoc false

  alias FunWithFlags.Store.{Cache, Persistent}


  def lookup(flag_name) do
    case Cache.get(flag_name) do
      {:ok, flag} ->
        {:ok, flag}
      {:miss, reason, stale_value_or_nil} ->
        case Persistent.get(flag_name) do
          {:ok, flag} ->
            Cache.put(flag) 
            {:ok, flag}
          {:error, _reason} ->
            try_to_use_the_cached_value(reason, stale_value_or_nil)
        end
    end
  end


  defp try_to_use_the_cached_value(:expired, value) do
    {:ok, value}
  end
  defp try_to_use_the_cached_value(_, _) do
    raise "Can't load feature flag"
  end


  def put(flag_name, gate) do
    case Persistent.put(flag_name, gate) do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end


  def delete(flag_name, gate) do
    case Persistent.delete(flag_name, gate) do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end


  def delete(flag_name) do
    case Persistent.delete(flag_name) do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end


  def reload(flag_name) do
    # IO.puts "reloading #{flag_name}"
    case Persistent.get(flag_name) do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end
end
