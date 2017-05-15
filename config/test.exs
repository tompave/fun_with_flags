use Mix.Config

config :fun_with_flags, :redis,
  database: 5

with_cache =
  case System.get_env("CACHE_ENABLED") do
    "false" -> false
    "0"     -> false
    _       -> true # default
  end

IO.puts "test config: with_cache = #{with_cache}"
config :fun_with_flags, :cache,
  enabled: with_cache,
  ttl: 60

config :logger, level: :error




if System.get_env("PUBSUB_BROKER") == "phoenix_pubsub" do
  config :fun_with_flags, :cache_bust_notifications, [
    adapter: FunWithFlags.Notifications.PhoenixPubSub,
    client: :fwf_test
  ]
end
