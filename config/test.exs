use Mix.Config

config :fun_with_flags, :redis,
  database: 5

config :logger, level: :error


persistence =
  case System.get_env("PERSISTENCE") do
    "ecto" -> :ecto
    _      -> :redis # default
  end


if persistence == :ecto do
  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_test",
    pool: Ecto.Adapters.SQL.Sandbox
end
