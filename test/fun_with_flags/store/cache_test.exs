defmodule FunWithFlags.Store.CacheTest do
  use FunWithFlags.TestCase, async: false # mocks!
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Store.Cache
  alias FunWithFlags.{Timestamps, Config, Flag, Gate}

  setup do
    Cache.flush()
    name = unique_atom()
    gate = %Gate{type: :boolean, enabled: true}
    flag = %Flag{name: name, gates: [gate]}
    {:ok, name: name, flag: flag }
  end


  describe "put(%Flag{})" do
    test "put(%Flag{}) changes the cahced flag", %{name: name, flag: flag} do
      assert {:miss, :not_found, nil} = Cache.get(name)
      Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)

      flag2 = %Flag{ flag | gates: [Gate.new(:boolean, false)]}

      Cache.put(flag2)
      assert {:ok, ^flag2} = Cache.get(name)
      refute match? {:ok, ^flag}, Cache.get(name)
    end

    test "put(%Flag{}) returns the tuple {:ok, %Flag{}}", %{flag: flag} do
      assert {:ok, ^flag} = Cache.put(flag)
    end
  end


  describe "get(:flag_name)" do
    test "looking up an undefined flag returns {:miss, :not_found, nil}" do
      flag_name = unique_atom()
      assert {:miss, :not_found, nil} = Cache.get(flag_name)
    end

    test "looking up an already stored flag returns {:ok, %Flag{}}", %{name: name, flag: flag} do
      assert {:miss, :not_found, nil} = Cache.get(name)
      Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)
    end


    test "looking up an expired flag returns {:miss, :expired, stale_value}", %{name: name, flag: flag} do
      assert {:miss, :not_found, nil} = Cache.get(name)

      {:ok, ^flag} = Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)

      # 1 second before expiring
      timetravel by: (Config.cache_ttl - 1) do
        assert {:ok, ^flag} = Cache.get(name)
      end

      # 1 second after expiring
      timetravel by: (Config.cache_ttl + 1) do
        assert {:miss, :expired, ^flag} = Cache.get(name)

        Cache.flush
        assert {:miss, :not_found, nil} = Cache.get(name)
      end
    end

    test "enabling ttl flutter introduces variance into expiration", %{name: name, flag: flag} do
      Mix.Config.persist(fun_with_flags: [cache: [flutter: true]])
      offset = Flag.flutter_offset(flag)

      assert {:miss, :not_found, nil} = Cache.get(name)

      {:ok, ^flag} = Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)

      # 1 second before expiring + offset
      timetravel by: (Config.cache_ttl + offset - 1) do
        assert {:ok, ^flag} = Cache.get(name)
      end

      # 1 second after expiring + offset
      timetravel by: (Config.cache_ttl + offset + 1) do
        assert {:miss, :expired, ^flag} = Cache.get(name)
      end

      # 1 second after original TTL
      timetravel by: (Config.cache_ttl + 1) do
        assert {:miss, :expired, ^flag} = Cache.get(name)
      end

      Mix.Config.persist(fun_with_flags: [cache: [flutter: false]])
    end
  end


  describe "integration: enable and disable with the top-level API" do
    setup do
      # can't use setup_all in here, but the on_exit should
      # be run only once because it's identifed by a common ref
      on_exit(:cache_integration_group, fn() -> clear_test_db() end)
      :ok
    end

    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = Cache.get(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = Cache.get(name)
    end
  end


  test "flush() empties the cache", %{flag: flag}  do
    Cache.put(flag)

    assert [{n, {f, t}}|_] = Cache.dump()
    assert is_atom(n)    # name
    assert %Flag{} = f   # value
    assert is_integer(t) # timestamp

    Cache.flush()
    assert [] = Cache.dump()
  end


  test "dump() returns a List with the cached keys", %{name: name1, flag: flag1} do
    # because the test is faster than one second
    now = Timestamps.now

    Cache.put(flag1)

    assert [{^name1, {^flag1, ^now}}|_] = Cache.dump()

    name2 = unique_atom()
    gate2 = %Gate{type: :boolean, enabled: true}
    flag2 = %Flag{name: name2, gates: [gate2]}
    Cache.put(flag2)

    name3 = unique_atom()
    gate3 = %Gate{type: :boolean, enabled: true}
    flag3 = %Flag{name: name3, gates: [gate3]}
    Cache.put(flag3)

    assert [{n, {f, t}}|_] = Cache.dump()
    assert is_atom(n)    # name
    assert %Flag{} = f   # value
    assert is_integer(t) # timestamp

    kw = Cache.dump()
    assert is_list(kw)
    assert {^flag1, ^now} = Keyword.get(kw, name1)
    assert {^flag2, ^now} = Keyword.get(kw, name2)
    assert {^flag3, ^now} = Keyword.get(kw, name3)
  end
end
