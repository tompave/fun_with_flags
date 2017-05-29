use Mix.Config

# config :fun_with_flags, :persistence,
#   [adapter: FunWithFlags.Store.Persistent.Redis]
# config :fun_with_flags, :cache_bust_notifications,
#   [enabled: true, adapter: FunWithFlags.Notifications.Redis]

persistence =
  case System.get_env("PERSISTENCE") do
    "ecto" -> :ecto
    _      -> :redis # default
  end


if persistence == :ecto do
  config :fun_with_flags, ecto_repos: [FunWithFlags.Dev.EctoRepo]

  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    adapter: Ecto.Adapters.Postgres,
    username: "postgres",
    password: "postgres",
    database: "fun_with_flags_dev",
    hostname: "localhost",
    pool_size: 10
end


case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
