defmodule FunWithFlags.TestUtils do
  @test_db 5
  @redis FunWithFlags.Store.Persistent

  # Since the flags are saved on shared storage (ETS and
  # Redis), in order to keep the tests isolated _and_ async
  # each test must use unique flag names. Not doing so would
  # cause some tests to override other tests flag values.
  #
  # This method should _never_ be used at runtime because
  # atoms are not garbage collected.
  #
  def unique_atom do
    :crypto.strong_rand_bytes(7)
    |> Base.encode32(padding: false, case: :lower)
    |> String.to_atom
  end

  def use_redis_test_db do
    Redix.command!(@redis, ["SELECT", @test_db])
  end

  def clear_redis_test_db do
    use_redis_test_db()

    Redix.command!(@redis, ["KEYS", "fun_with_flags:*"])
    |> delete_keys()
  end

  defp delete_keys([]), do: 0
  defp delete_keys(keys) do
    Redix.command!(@redis, ["DEL" | keys])
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

end
