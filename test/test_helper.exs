# If we are not using Ecto and we're not using Phoenix.PubSub, then
# we need a Redis instance for either persistence or PubSub.
does_anything_need_redis =
  !(FunWithFlags.Config.persist_in_ecto?() && FunWithFlags.Config.phoenix_pubsub?())

if FunWithFlags.Config.phoenix_pubsub?() do
  # Start a Phoenix.PubSub process for the tests.
  # The `:fwf_test` connection name will be injected into this
  # library in `config/test.exs`.
  {:ok, _pid} = Phoenix.PubSub.PG2.start_link(:fwf_test, pool_size: 1)
end

# With some configurations the tests are run with `--no-start`, because
# we want to start the Phoenix.PubSub process before starting the application.
Application.ensure_all_started(:fun_with_flags)
IO.puts("--------------------------------------------------------------")
IO.puts("$TEST_OPTS='#{System.get_env("TEST_OPTS")}'")
IO.puts("$CACHE_ENABLED=#{System.get_env("CACHE_ENABLED")}")
IO.puts("$PERSISTENCE=#{System.get_env("PERSISTENCE")}")
IO.puts("$PUBSUB_BROKER=#{System.get_env("PUBSUB_BROKER")}")
IO.puts("--------------------------------------------------------------")
IO.puts("Cache enabled:         #{inspect(FunWithFlags.Config.cache?())}")
IO.puts("Persistence adapter:   #{inspect(FunWithFlags.Config.persistence_adapter())}")
IO.puts("Notifications adapter: #{inspect(FunWithFlags.Config.notifications_adapter())}")
IO.puts("Anything using Redis:  #{inspect(does_anything_need_redis)}")
IO.puts("--------------------------------------------------------------")

if does_anything_need_redis do
  FunWithFlags.TestUtils.use_redis_test_db()
end

ExUnit.start()

if FunWithFlags.Config.persist_in_ecto?() do
  {:ok, _pid} = FunWithFlags.Dev.EctoRepo.start_link()
  Ecto.Adapters.SQL.Sandbox.mode(FunWithFlags.Dev.EctoRepo, :manual)
end
