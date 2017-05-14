use Mix.Config

# config :fun_with_flags, :persistence_adapter, FunWithFlags.Store.Persistent.Redis
# config :fun_with_flags, :notifications_adapter, FunWithFlags.Notifications.Redis
# config :fun_with_flags, cache_bust_notifications: true


case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
