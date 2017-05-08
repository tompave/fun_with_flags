defmodule FunWithFlags.Store do
  @moduledoc false

  require Logger
  alias FunWithFlags.Store.Cache
  @persistence FunWithFlags.Store.Persistent.adapter


  def lookup(flag_name) do
    case Cache.get(flag_name) do
      {:ok, flag} ->
        {:ok, flag}
      {:miss, reason, stale_value_or_nil} ->
        case @persistence.get(flag_name) do
          {:ok, flag} ->
            Cache.put(flag) 
            {:ok, flag}
          {:error, _reason} ->
            try_to_use_the_cached_value(reason, stale_value_or_nil, flag_name)
        end
    end
  end


  defp try_to_use_the_cached_value(:expired, value, flag_name) do
    Logger.warn "FunWithFlags: couldn't load flag '#{flag_name}' from storage, falling back to stale cached value from ETS"
    {:ok, value}
  end
  defp try_to_use_the_cached_value(_, _, flag_name) do
    raise "Can't load feature flag '#{flag_name}' from neither storage nor the cache"
  end


  def put(flag_name, gate) do
    @persistence.put(flag_name, gate)
    |> cache_persistence_result()
  end


  def delete(flag_name, gate) do
    @persistence.delete(flag_name, gate)
    |> cache_persistence_result()
  end


  def delete(flag_name) do
    @persistence.delete(flag_name)
    |> cache_persistence_result()
  end


  def reload(flag_name) do
    Logger.debug("FunWithFlags: reloading cached flag '#{flag_name}' from storage ")
    @persistence.get(flag_name)
    |> cache_persistence_result()
  end


  defdelegate all_flags(), to: @persistence
  defdelegate all_flag_names(), to: @persistence


  defp cache_persistence_result(result) do
    case result do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end
end
