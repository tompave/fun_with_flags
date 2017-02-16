defmodule FunWithFlags.Store.CacheTest do
  use ExUnit.Case, async: false # mocks!
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Store.Cache
  alias FunWithFlags.{Timestamps, Config}

  # No need to start it as it's in the supervision tree, but:
  #
  # setup_all do
  #   {:ok, _cache} = Cache.start_link
  #   :ok
  # end

  describe "put()" do
    test "put() can change the value of a flag" do
      flag_name = unique_atom()

      assert {:miss, :not_found} = Cache.get(flag_name)
      Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)
      Cache.put(flag_name, false)
      assert {:ok, false} = Cache.get(flag_name)
    end

    test "put() returns the tuple {:ok, a_boolean_value}" do
      flag_name = unique_atom()
      assert {:ok, true} = Cache.put(flag_name, true)
      assert {:ok, false} = Cache.put(flag_name, false)
    end
  end

  describe "get()" do
    test "looking up an undefined flag returns {:miss, :not_found}" do
      flag_name = unique_atom()
      assert {:miss, :not_found} = Cache.get(flag_name)
    end

    test "get() checks if a flag is already stored, it returns {:ok, flag_value} or {:miss, :not_found}" do
      flag_name = unique_atom()
      assert {:miss, :not_found} = Cache.get(flag_name)
      Cache.put(flag_name, false)
      assert {:ok, false} = Cache.get(flag_name)
      Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)
    end

    test "looking up an expired flag returns {:miss, :expired}" do
      flag_name = unique_atom()
      assert {:miss, :not_found} = Cache.get(flag_name)

      now = Timestamps.now
      {:ok, true} = Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)

      the_ttl = Config.cache_ttl

      # 1 second before expiring
      with_mock(Timestamps, [
        now: fn() -> now + (the_ttl - 1) end,
        expired?: fn(^now, ^the_ttl) -> :meck.passthrough([now, the_ttl]) end
      ]) do
        assert {:ok, true} = Cache.get(flag_name)
      end

      # 1 second after expiring
      with_mock(Timestamps, [
        now: fn() -> now + (the_ttl + 1) end,
        expired?: fn(^now, ^the_ttl) -> :meck.passthrough([now, the_ttl]) end
      ]) do
        assert {:miss, :expired} = Cache.get(flag_name)

        Cache.flush
        assert {:miss, :not_found} = Cache.get(flag_name)
      end
    end
  end


  describe "unit: enable and disable with this module's API" do
    test "looking up a disabled flag returns {:found, false}" do
      flag_name = unique_atom()
      {:ok, false} = Cache.put(flag_name, false)
      assert {:ok, false} = Cache.get(flag_name)
    end

    test "looking up an enabled flag returns {:ok, true}" do
      flag_name = unique_atom()
      {:ok, true} = Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)
    end
  end

  describe "integration: enable and disable with the top-level API" do
    setup do
      # can't use setup_all in here, but the on_exit should
      # be run only once because it's identifed by a common ref
      on_exit(:cache_integration_group, fn() -> clear_redis_test_db() end)
      :ok
    end

    test "looking up a disabled flag returns {:ok, false}" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert {:ok, false} = Cache.get(flag_name)
    end

    test "looking up an enabled flag returns {:ok, true}" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert {:ok, true} = Cache.get(flag_name)
    end
  end

  test "flush() empties the cache" do
    flag_name = unique_atom()
    Cache.put(flag_name, true)

    assert [{n, {v, t}}|_] = Cache.dump()
    assert is_atom(n)    # name
    assert is_boolean(v) # value
    assert is_integer(t) # timestamp

    Cache.flush()
    assert [] = Cache.dump()
  end


  test "dump() returns a List with the cached keys" do
    # because the test is faster than one second
    now = Timestamps.now

    one = unique_atom()
    Cache.put(one, true)
    two = unique_atom()
    Cache.put(two, true)
    three = unique_atom()
    Cache.put(three, false)

    assert [{n, {v, t}}|_] = Cache.dump()
    assert is_atom(n)    # name
    assert is_boolean(v) # value
    assert is_integer(t) # timestamp

    kw = Cache.dump()
    assert is_list(kw)
    assert {true, ^now} = Keyword.get(kw, one)
    assert {true, ^now} = Keyword.get(kw, two)
    assert {false, ^now} = Keyword.get(kw, three)
  end
end
