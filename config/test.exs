use Mix.Config

IO.puts "Loading config for default test env"

config :fun_with_flags, :redis,
  database: 5

config :fun_with_flags, :cache,
  enabled: true,
  ttl: 60

config :logger, level: :error
