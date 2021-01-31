defmodule FunWithFlags.Store do
  @moduledoc false

  require Logger
  alias FunWithFlags.Store.Cache
  alias FunWithFlags.{Flag, Config}

  import FunWithFlags.Config, only: [persistence_adapter: 0]

  def lookup(flag_name) when is_atom(flag_name) do
    case Cache.get(flag_name) do
      {:ok, flag} ->
        {:ok, flag}
      {:miss, reason, stale_value_or_nil} ->
        case persistence_adapter().get(flag_name) do
          {:ok, flag} ->
            Cache.put(flag)
            {:ok, flag}
          {:error, _reason} ->
            try_to_use_the_cached_value(reason, stale_value_or_nil, flag_name)
        end
    end
  end

  def lookup(flag_names) when is_list(flag_names) do
    flags =
      flag_names
      |> Task.async_stream(fn flag_name -> {flag_name, Cache.get(flag_name)} end)
      |> Enum.map(fn {:ok, result} -> result end)

    cached_flags =
      flags
      |> Enum.filter(fn
        {_, {:ok, _flag}} -> true
        _ -> false
      end)
      |> Enum.map(fn {_, {:ok, flag}} -> flag end)

    missing_flags =
      flags
      |> Enum.filter(fn
        {_, {:miss, _, _}} -> true
        _ -> false
      end)
      |> Enum.map(fn {_, {:miss, _, _}} = missing_flag -> missing_flag end)

    fetched_flags =
      missing_flags
      |> Enum.map(fn {flag_name, _} -> flag_name end)
      |> persistence_adapter().get_many()
      |> Enum.map(fn
        {:ok, {_, flag}} ->
          Cache.put(flag)
          flag

        {:error, {flag_name, _why}} ->
          {_flag_name, {:miss, reason, stale_value_or_nil}} =
            Enum.find(missing_flags, fn {name, _} ->
              name == flag_name
            end)

          {:ok, flag} = try_to_use_the_cached_value(reason, stale_value_or_nil, flag_name)
          flag
      end)

    {:ok, fetched_flags ++ cached_flags}
  end


  defp try_to_use_the_cached_value(:expired, value, flag_name) do
    Logger.warn "FunWithFlags: couldn't load flag '#{flag_name}' from storage, falling back to stale cached value from ETS"
    {:ok, value}
  end
  defp try_to_use_the_cached_value(_, _, flag_name) do
    raise "Can't load feature flag '#{flag_name}' from neither storage nor the cache"
  end


  def put(flag_name, gate) do
    flag_name
    |> persistence_adapter().put(gate)
    |> publish_change()
    |> cache_persistence_result()
  end


  def delete(flag_name, gate) do
    flag_name
    |> persistence_adapter().delete(gate)
    |> publish_change()
    |> cache_persistence_result()
  end


  def delete(flag_name) do
    flag_name
    |> persistence_adapter().delete()
    |> publish_change()
    |> cache_persistence_result()
  end


  def reload(flag_name) do
    Logger.debug fn -> "FunWithFlags: reloading cached flag '#{flag_name}' from storage " end
    flag_name
    |> persistence_adapter().get()
    |> cache_persistence_result()
  end


  defdelegate all_flags(), to: persistence_adapter()
  defdelegate all_flag_names(), to: persistence_adapter()


  defp cache_persistence_result(result) do
    case result do
      {:ok, flag} ->
        Cache.put(flag)
      {:error, _reason} = error ->
        error
    end
  end


  defp publish_change(result = {:ok, %Flag{name: flag_name}}) do
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end

    result
  end

  defp publish_change(result) do
    result
  end
end
