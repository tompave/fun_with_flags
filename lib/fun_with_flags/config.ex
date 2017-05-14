defmodule FunWithFlags.Config do
  @moduledoc false
  @default_redis_config [
    host: "localhost",
    port: 6379,
    database: 0,
  ]

  @default_cache_config [
    enabled: true,
    ttl: 900 # in seconds, 15 minutes
  ]

  @default_notifications_config [
    enabled: true,
    adapter: FunWithFlags.Notifications.Redis
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


  # If we're not using the cache, then don't bother with
  # the 2-level logic in the default Store module.
  #
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
      :persistence,
      [adapter: FunWithFlags.Store.Persistent.Redis]
    )
    |> Keyword.get(:adapter)
  end


  defp notifications_config do
    Keyword.merge(
      @default_notifications_config,
      Application.get_env(:fun_with_flags, :cache_bust_notifications, [])
    )
  end


  # Defaults to FunWithFlags.Notifications.Redis
  #
  def notifications_adapter do
    Keyword.get(notifications_config(), :adapter)
  end


  # Should the application emir cache busting/syncing notifications?
  # Defaults to false if we are not using a cache and if there is no
  # notifications adapter configured. Else, it defaults to true.
  #
  def change_notifications_enabled? do
    cache?() &&
    notifications_adapter() &&
    Keyword.get(notifications_config(), :enabled)
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
