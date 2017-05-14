use Mix.Config

# config :fun_with_flags, :persistence,
#   [adapter: FunWithFlags.Store.Persistent.Redis]
# config :fun_with_flags, :cache_bust_notifications,
#   [enabled: true, adapter: FunWithFlags.Notifications.Redis]


case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
