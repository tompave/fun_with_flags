# If we are not using Ecto and we're not using Phoenix.PubSub, then
# we need a Redis instance for either persistence or PubSub.
does_anything_need_redis = !(
  FunWithFlags.Config.persist_in_ecto? && FunWithFlags.Config.phoenix_pubsub?
)


if FunWithFlags.Config.phoenix_pubsub? do
  # The Phoenix PubSub application must be running before we try to start our
  # PubSub process and subscribe.
  :ok = Application.ensure_started(:phoenix_pubsub)

  # Start a Phoenix.PubSub process for the tests.
  # The `:fwf_test` connection name will be injected into this
  # library in `config/test.exs`.
  children = [
    {Phoenix.PubSub, [name: :fwf_test, adapter: Phoenix.PubSub.PG2, pool_size: 1]}
  ]
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  {:ok, _pid} = Supervisor.start_link(children, opts)
end

IO.puts "--------------------------------------------------------------"
IO.puts "$CACHE_ENABLED=#{System.get_env("CACHE_ENABLED")}"
IO.puts "$PERSISTENCE=#{System.get_env("PERSISTENCE")}"
IO.puts "$RDBMS=#{System.get_env("RDBMS")}"
IO.puts "$PUBSUB_BROKER=#{System.get_env("PUBSUB_BROKER")}"
IO.puts "$CI=#{System.get_env("CI")}"
IO.puts "--------------------------------------------------------------"
IO.puts "Elixir version:        #{System.version()}"
IO.puts "Erlang/OTP version:    #{:erlang.system_info(:system_version) |> to_string() |> String.trim_trailing()}"
IO.puts "Logger level:          #{inspect(Logger.level())}"
IO.puts "Cache enabled:         #{inspect(FunWithFlags.Config.cache?)}"
IO.puts "Persistence adapter:   #{inspect(FunWithFlags.Config.persistence_adapter())}"
IO.puts "RDBMS driver:          #{inspect(if FunWithFlags.Config.persist_in_ecto?, do: FunWithFlags.Dev.EctoRepo.__adapter__(), else: nil)}"
IO.puts "Notifications adapter: #{inspect(FunWithFlags.Config.notifications_adapter())}"
IO.puts "Anything using Redis:  #{inspect(does_anything_need_redis)}"
IO.puts "--------------------------------------------------------------"

if does_anything_need_redis do
  FunWithFlags.TestUtils.use_redis_test_db()
end

FunWithFlags.Supervisor.start_link(nil)

ExUnit.start()

if FunWithFlags.Config.persist_in_ecto? do
  {:ok, _pid} = FunWithFlags.Dev.EctoRepo.start_link()
  Ecto.Adapters.SQL.Sandbox.mode(FunWithFlags.Dev.EctoRepo, :manual)
end
