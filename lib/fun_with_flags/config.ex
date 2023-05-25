defmodule FunWithFlags.Config do
  require Application

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

  @default_persistence_config [
    adapter: FunWithFlags.Store.Persistent.Redis,
    repo: FunWithFlags.NullEctoRepo,
    ecto_table_name: "fun_with_flags_toggles",
    ecto_primary_key_type: :id
  ]

  def redis_config do
    case Application.get_env(:fun_with_flags, :redis, []) do
      uri  when is_binary(uri) ->
        uri
      {uri, opts} when is_binary(uri) and is_list(opts) ->
        {uri, opts}
      opts when is_list(opts) ->
        if Keyword.has_key?(opts, :sentinel) do
          @default_redis_config
          |> Keyword.take([:database])
          |> Keyword.merge(opts)
        else
          Keyword.merge(@default_redis_config, opts)
        end
      {:system, var} when is_binary(var) ->
        System.get_env(var)
    end
  end


  def cache? do
    Keyword.get(ets_cache_config(), :enabled)
  end


  def cache_ttl do
    Keyword.get(ets_cache_config(), :ttl)
  end


  def ets_cache_config do
    Keyword.merge(
      @default_cache_config,
      Application.get_env(:fun_with_flags, :cache, [])
    )
  end

  # Used to determine the store module at compile time, which is stored in a
  # module attribute. `Application.compile_env` cannot be used in functions,
  # so here we are.
  @compile_time_cache_config Application.compile_env(:fun_with_flags, :cache, [])

  # If we're not using the cache, then don't bother with
  # the 2-level logic in the default Store module.
  #
  def store_module_determined_at_compile_time do
    cache_conf = Keyword.merge(
      @default_cache_config,
      @compile_time_cache_config
    )

    if Keyword.get(cache_conf, :enabled) do
      FunWithFlags.Store
    else
      FunWithFlags.SimpleStore
    end
  end


  # Used to determine the Ecto table name at compile time.
  @compile_time_persistence_config Application.compile_env(:fun_with_flags, :persistence, [])


  def ecto_table_name_determined_at_compile_time do
    pers_conf = Keyword.merge(
      @default_persistence_config,
      @compile_time_persistence_config
    )
    Keyword.get(pers_conf, :ecto_table_name)
  end


  def ecto_primary_key_type_determined_at_compile_time do
    pers_conf = Keyword.merge(
      @default_persistence_config,
      @compile_time_persistence_config
    )
    Keyword.get(pers_conf, :ecto_primary_key_type)
  end


  defp persistence_config do
    Keyword.merge(
      @default_persistence_config,
      Application.get_env(:fun_with_flags, :persistence, [])
    )
  end

  # Defaults to FunWithFlags.Store.Persistent.Redis
  #
  def persistence_adapter do
    Keyword.get(persistence_config(), :adapter)
  end


  def ecto_repo do
    Keyword.get(persistence_config(), :repo)
  end


  def persist_in_ecto? do
    persistence_adapter() == FunWithFlags.Store.Persistent.Ecto
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


  def phoenix_pubsub? do
    notifications_adapter() == FunWithFlags.Notifications.PhoenixPubSub
  end


  def pubsub_client do
    Keyword.get(notifications_config(), :client)
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
