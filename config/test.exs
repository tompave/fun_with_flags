use Mix.Config

config :fun_with_flags, :redis,
  database: 5

config :logger, level: :error


if System.get_env("PERSISTENCE") == "ecto" do
  config :fun_with_flags, FunWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_test",
    pool: Ecto.Adapters.SQL.Sandbox
end
