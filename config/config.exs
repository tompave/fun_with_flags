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

  # To test the compile-time config warnings.
  # config :fun_with_flags, :persistence,
  #   ecto_table_name: System.get_env("ECTO_TABLE_NAME", "fun_with_flags_toggles")

  # ecto's config
  config :fun_with_flags, ecto_repos: [FunWithFlags.Dev.EctoRepo]

  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_dev",
    hostname: "localhost",
    pool_size: 10

  case System.get_env("RDBMS") do
    "mysql" ->
      mysql_password = case System.get_env("CI") do
        "true" -> "root" # On GitHub Actions.
        _      -> ""     # For a default dev-insecure installation, e.g. via Homebrew on macOS.
      end

      config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
        username: "root",
        password: mysql_password
    "sqlite" ->
      config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
        username: "sqlite",
        password: "sqlite"
    _ ->
      config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
        username: "postgres",
        password: "postgres"
  end
end

# -------------------------------------------------
# Import
#
case config_env() do
  :test -> import_config "test.exs"
  _     -> nil
end
