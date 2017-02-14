defmodule FunWithFlags.Config do
  @moduledoc false
  @default_redis_config [
    host: 'localhost',
    port: 6379,
  ]

  @default_cache_config [
    enabled: true,
  ]

  def redis_config do
    case Application.get_env(:fun_with_flags, :redis, []) do
      uri  when is_binary(uri) ->
        uri
      opts when is_list(opts) ->
        Keyword.merge(@default_redis_config, opts)
    end
  end


  def cache? do
    Keyword.get(ets_cache_config(), :enabled)
  end


  defp ets_cache_config do
    Keyword.merge(
      @default_cache_config,
      Application.get_env(:fun_with_flags, :cache, [])
    )
  end


  def store_module do
    if __MODULE__.cache? do
      FunWithFlags.Store
    else
      FunWithFlags.SimpleStore
    end
  end
end
