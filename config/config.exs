use Mix.Config

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


# -------------------------------------------------
# Import

case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
