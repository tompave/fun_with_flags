use Mix.Config

IO.puts "Loading config for the \"no cache\" integration test env"

config :fun_with_flags, :redis,
  database: 5

config :fun_with_flags, :cache,
  enabled: false
