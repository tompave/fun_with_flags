IO.puts "$PUBSUB_BROKER=#{System.get_env("PUBSUB_BROKER") }"

# By default exclude the phoenix pubsub tests.
ExUnit.configure exclude: [
  :phoenix_pubsub,
]

if System.get_env("PUBSUB_BROKER") == "phoenix_pubsub" do
  # Start a Phoenix.PubSub process for the tests.
  # The `:fwf_test` connection name will be injected into this
  # library in `config/test..exs`.
  {:ok, _pid} = Phoenix.PubSub.PG2.start_link(:fwf_test, [pool_size: 1])
end

# With some configurations the tests are run with `--no-start`, because
# we want to start the Phoenix.PubSub process before starting the application.
Application.ensure_all_started(:fun_with_flags)

IO.puts "Running tests with $TEST_OPTS='#{System.get_env("TEST_OPTS")}'"
IO.puts "Notifications adapter: #{inspect(FunWithFlags.Config.notifications_adapter())}"

FunWithFlags.TestUtils.use_redis_test_db()
ExUnit.start()
