import Config

# config :fun_with_flags, :persistence,
#   [adapter: FunWithFlags.Store.Persistent.Redis]
# config :fun_with_flags, :cache_bust_notifications,
#   [enabled: true, adapter: FunWithFlags.Notifications.Redis]


# -------------------------------------------------
# Extract from the ENV

with_cache =
  case System.get_env("CACHE_ENABLED") do
    "false" -> false
    "0"     -> false
    _       -> true # default
  end

with_phx_pubsub =
  case System.get_env("PUBSUB_BROKER") do
    "phoenix_pubsub" -> true
    _ -> false
  end

with_ecto =
  case System.get_env("PERSISTENCE") do
    "ecto" -> true
    _      -> false # default
  end


# -------------------------------------------------
# Configuration

config :fun_with_flags, :cache,
  enabled: with_cache,
  ttl: 60


if with_phx_pubsub do
  config :fun_with_flags, :cache_bust_notifications, [
    adapter: FunWithFlags.Notifications.PhoenixPubSub,
    client: :fwf_test
  ]
end


if with_ecto do
  # this library's config
  config :fun_with_flags, :persistence,
    adapter: FunWithFlags.Store.Persistent.Ecto,
    repo: FunWithFlags.Dev.EctoRepo

  # ecto's config
  config :fun_with_flags, ecto_repos: [FunWithFlags.Dev.EctoRepo]

  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_dev",
    hostname: "localhost",
    pool_size: 10

  case System.get_env("RDBMS") do
    "mysql" ->
      config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
        username: "root",
        password: "root"
    _ ->
      config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
        username: "postgres",
        password: "postgres"
  end
end

# -------------------------------------------------
# Import
#
# Unfortunately `Config.config_env/0` was introduced in Elixir 1.11.
# In Elixir 1.10, `Mix.Env/0` must be used to check the current env.
#
# TODO: When support for Elixir 1.10 is dropped, update this to use
#       `config_env()` instead.
#
current_env =
  if Version.compare(System.version(), "1.11.0") == :lt do
    Mix.env()
  else
    config_env()
  end

case current_env do
  :test -> import_config "test.exs"
  _     -> nil
end
