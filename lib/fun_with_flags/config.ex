defmodule FunWithFlags.Config do
  @moduledoc false
  @default_redis_config [
    host: 'localhost',
    port: 6379,
    database: 0,
  ]

  @default_cache_config [
    enabled: true,
    ttl: 900 # in seconds, 15 minutes
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

  def cache_ttl do
    Keyword.get(ets_cache_config(), :ttl)
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


  # Defaults to FunWithFlags.Store.Persistent.Redis
  #
  def persistence_adapter do
    Application.get_env(
      :fun_with_flags,
      :persistence_adapter,
      FunWithFlags.Store.Persistent.Redis
    )
  end

  # I can't use Kernel.make_ref/0 because this needs to be
  # serializable to a string and sent via Redis.
  # Erlang References lose a lot of "uniqueness" when
  # represented as binaries.
  #
  def build_unique_id do
    (:crypto.strong_rand_bytes(10) <> inspect(:os.timestamp()))
    |> Base.url_encode64(padding: false)
  end
end
