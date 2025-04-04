defmodule FunWithFlags.TestUtils do
  alias FunWithFlags.Config
  import ExUnit.Assertions, only: [assert: 1]

  @test_db 5
  @redis FunWithFlags.Store.Persistent.Redis

  # Since the flags are saved on shared storage (ETS and
  # Redis), in order to keep the tests isolated _and_ async
  # each test must use unique flag names. Not doing so would
  # cause some tests to override other tests flag values.
  #
  # This method should _never_ be used at runtime because
  # atoms are not garbage collected.
  #
  def unique_atom do
    String.to_atom(random_string())
  end

  def random_string do
    :crypto.strong_rand_bytes(7)
    |> Base.encode32(padding: false, case: :lower)
  end

  def use_redis_test_db do
    Redix.command!(@redis, ["SELECT", @test_db])
  end

  def clear_test_db do
    unless Config.persist_in_ecto? do
      use_redis_test_db()

      Redix.command!(@redis, ["DEL", "fun_with_flags"])
      Redix.command!(@redis, ["KEYS", "fun_with_flags:*"])
      |> delete_keys()
    end
  end

  defp delete_keys([]), do: 0
  defp delete_keys(keys) do
    Redix.command!(@redis, ["DEL" | keys])
  end

  def clear_cache do
    if Config.cache? do
      FunWithFlags.Store.Cache.flush()
    end
  end

  defmacro timetravel([by: offset], [do: body]) do
    quote do
      fake_now = FunWithFlags.Timestamps.now + unquote(offset)
      # IO.puts("now:      #{FunWithFlags.Timestamps.now}")
      # IO.puts("offset:   #{unquote(offset)}")
      # IO.puts("fake_now: #{fake_now}")

      with_mock(FunWithFlags.Timestamps, [
        now: fn() ->
          fake_now
        end,
        expired?: fn(timestamp, ttl) ->
          :meck.passthrough([timestamp, ttl])
        end
      ]) do
        unquote(body)
      end
    end
  end

  def kill_process(name) do
    true = GenServer.whereis(name) |> Process.exit(:kill)
  end

  def configure_redis_with(conf) do
    Application.put_all_env(fun_with_flags: [redis: conf])
    assert ^conf = Application.get_env(:fun_with_flags, :redis)
  end

  def ensure_default_redis_config_in_app_env do
    assert match?([database: 5], Application.get_env(:fun_with_flags, :redis))
  end

  def reset_app_env_to_default_redis_config do
    configure_redis_with([database: 5])
  end

  def phx_pubsub_ready? do
    try do
      Process.whereis(FunWithFlags.Notifications.PhoenixPubSub) &&
        FunWithFlags.Notifications.PhoenixPubSub.subscribed?
    catch
      :exit, _reason ->
        # This is to catch failures when the GenServer is still recovering from `Process.exit(:kill)`,
        # as in that case this function might fail with:
        #   (EXIT) no process: the process is not alive or there's no process currently associated with the given name, possibly because its application isn't started
        #
        # I'm not entirely sure about the sequencing here. I'd suppose that `Process.whereis()` should
        # protect us from that, but likely there is a race condition somewhere so that the GenServer is
        # exited/killed after the `whereis()` call has returned a truthy value.

        # IO.puts "EXIT while checking for Phoenix Pubsub readiness: #{inspect reason}"
        false
    end
  end

  def wait_until_pubsub_is_ready!(attempts \\ 20, wait_time_ms \\ 25)

  def wait_until_pubsub_is_ready!(attempts, wait_time_ms) when attempts > 0 do
    case phx_pubsub_ready?() do
      true ->
        :ok
      _ ->
        :timer.sleep(wait_time_ms)
        wait_until_pubsub_is_ready!(attempts - 1, wait_time_ms)
    end
  end

  def wait_until_pubsub_is_ready!(_, _) do
    raise "Phoenix PubSub is never ready, giving up"
  end

  def assert_with_retries(attempts \\ 30, wait_time_ms \\ 25, test_fn) do
    try do
      test_fn.()
    rescue
      e ->
        if attempts == 1 do
          reraise e, __STACKTRACE__
        else
          IO.write("|")
          :timer.sleep(wait_time_ms)
          assert_with_retries(attempts - 1, wait_time_ms, test_fn)
        end
    end
  end
end
