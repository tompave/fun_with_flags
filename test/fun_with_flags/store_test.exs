defmodule FunWithFlags.StoreTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.{Store, Config, Flag, Gate}
  alias FunWithFlags.Store.{Cache, Persistent}

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end

  setup do
    Cache.flush()
    name = unique_atom()
    gate = %Gate{type: :boolean, enabled: true}
    flag = %Flag{name: name, gates: [gate]}
    {:ok, name: name, gate: gate, flag: flag}
  end


  describe "lookup(flag_name)" do
    test "looking up an undefined flag returns a flag with no gates" do
      flag_name = unique_atom()
      assert %Flag{name: ^flag_name, gates: []} = Store.lookup(flag_name)
    end

    test "looking up a defined flag returns the flag", %{name: name, gate: gate, flag: flag} do
      assert %Flag{name: ^name, gates: []} = Store.lookup(name)
      Store.put(name, gate)
      assert ^flag = Store.lookup(name)
    end
  end


  describe "put(flag_name, value)" do
    test "put() can change the value of a flag", %{name: name, gate: gate, flag: flag} do
      assert %Flag{name: ^name, gates: []} = Store.lookup(name)

      Store.put(name, gate)
      assert ^flag = Store.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      Store.put(name, gate2)
      assert %Flag{name: ^name, gates: [^gate2]} = Store.lookup(name)
      refute match? ^flag, Store.lookup(name)
    end

    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, ^flag} = Store.put(name, gate)
    end
  end


  describe "reload(flag_name) reads the flag value from Redis and updates the Cache" do
    test "if the flag is not found in Redis, it sets it to false in the Cache", %{name: name, flag: flag} do
      empty_flag = %Flag{name: name, gates: []}
      assert {:ok, ^empty_flag} = Persistent.get(name)
      assert {:miss, :not_found, nil} = Cache.get(name)
      assert ^empty_flag = Store.lookup(name)

      Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)
      assert ^flag = Store.lookup(name)

      Store.reload(name)

      assert {:ok, ^empty_flag} = Cache.get(name)
      assert ^empty_flag = Store.lookup(name)
    end



    test "if the flag is stored in Redis, it stores it in the Cache", %{name: name, gate: gate, flag: flag} do
      {:ok, ^flag} = Persistent.put(name, gate)
      assert {:ok, ^flag} = Persistent.get(name)

      gate2 = %Gate{gate | enabled: false}
      flag2 = %Flag{name: name, gates: [gate2]}

      Cache.put(flag2)
      assert {:ok, ^flag2} = Cache.get(name)
      assert ^flag2 = Store.lookup(name)
      refute match? ^flag, Store.lookup(name)

      Store.reload(name)

      assert {:ok, ^flag} = Cache.get(name)
      assert ^flag = Store.lookup(name)
      refute match? ^flag2, Store.lookup(name)
    end
  end


  # describe "integration: enable and disable with the top-level API" do
  #   test "looking up a disabled flag returns false" do
  #     flag_name = unique_atom()
  #     FunWithFlags.disable(flag_name)
  #     assert false == Store.lookup(flag_name)
  #   end

  #   test "looking up an enabled flag returns true" do
  #     flag_name = unique_atom()
  #     FunWithFlags.enable(flag_name)
  #     assert true == Store.lookup(flag_name)
  #   end
  # end


  describe "integration: Cache and Persistence" do
    test "if we have a Cached value, the Persistent store is not touched at all", %{name: name, flag: flag} do
      Cache.put(flag)

      with_mocks([
        {Persistent, [:passthrough], []},
        {Cache, [:passthrough], []}
      ]) do
        assert ^flag = Store.lookup(name)
        assert called(Cache.get(name))
        refute called(Persistent.get(name))
      end
    end



    test "setting a value will update both the cache and the persistent store", %{name: name, gate: gate, flag: flag} do
      empty_flag = %Flag{name: name, gates: []}

      assert {:miss, :not_found, nil} == Cache.get(name)
      assert {:ok, ^empty_flag} = Persistent.get(name)

      Store.put(name, gate)
      assert {:ok, ^flag} = Cache.get(name)
      assert {:ok, ^flag} = Persistent.get(name)
    end

    test "when the value is initially not in the cache but set in redis,
          looking it up will populate the cache", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)

      assert {:miss, :not_found, nil} = Cache.get(name)
      assert {:ok, ^flag} = Persistent.get(name)
      
      assert ^flag = Store.lookup(name)
      assert {:ok, ^flag} = Cache.get(name)
    end


    test "when the value is initially not in the cache and not in redis,
          looking it up will populate the cache", %{name: name} do
      empty_flag = %Flag{name: name, gates: []}

      assert {:miss, :not_found, nil} == Cache.get(name)
      assert {:ok, ^empty_flag} = Persistent.get(name)

      assert ^empty_flag = Store.lookup(name)
      assert {:ok, ^empty_flag} = Cache.get(name)
    end


    test "put() will change both the value stored in the Cache and in Redis", %{name: name, gate: gate, flag: flag} do
      {:ok, ^flag} = Persistent.put(name, gate)
      {:ok, ^flag} = Cache.put(flag)

      assert {:ok, ^flag} = Cache.get(name)
      assert {:ok, ^flag} = Persistent.get(name)

      gate2 = %Gate{gate | enabled: false}
      flag2 = %Flag{name: name, gates: [gate2]}

      {:ok, ^flag2} = Store.put(name, gate2)

      assert {:ok, ^flag2} = Cache.get(name)
      assert {:ok, ^flag2} = Persistent.get(name)
    end


    test "when a value in the cache expires, it will load it from redis
          and update the cache", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)

      assert {:miss, :not_found, nil} = Cache.get(name)
      assert {:ok, ^flag} = Persistent.get(name)

      assert ^flag = Store.lookup(name)
      assert {:ok, ^flag} = Cache.get(name)

      timetravel by: (Config.cache_ttl + 1) do
        assert {:miss, :expired, ^flag} = Cache.get(name)
        assert ^flag = Store.lookup(name)
        assert {:ok, ^flag} = Cache.get(name)
      end
    end
  end


  describe "in case of Persistent store failure" do
    alias FunWithFlags.Store.{Cache, Persistent}

    test "if we have a Cached value, the Persistent store is not touched at all", %{name: name, flag: flag} do
      Cache.put(flag)

      with_mocks([
        {Persistent, [], get: fn(^name) -> {:error, "mocked error"} end},
        {Cache, [:passthrough], []}
      ]) do
        assert ^flag = Store.lookup(name)
        assert called(Cache.get(name))
        refute called(Persistent.get(name))
      end
    end


    test "if the Cached value is expired, it will still be used", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)
      assert ^flag = Store.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      flag2 = %Flag{name: name, gates: [gate2]}

      Cache.put(flag2)
      assert {:ok, ^flag2} = Cache.get(name)

      timetravel by: (Config.cache_ttl + 1) do
        with_mock(Persistent, [], get: fn(^name) -> {:error, "mocked error"} end) do
          assert ^flag2 = Store.lookup(name)
          assert {:miss, :expired, ^flag2} = Cache.get(name)
          assert called(Persistent.get(name))
          assert {:error, "mocked error"} = Persistent.get(name)
        end
      end
    end


    test "if there is no cached value, it raises an error", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)
      assert ^flag = Store.lookup(name)

      Cache.flush()
      assert {:miss, :not_found, nil} = Cache.get(name)

      with_mock(Persistent, [], get: fn(^name) -> {:error, "mocked error"} end) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          Store.lookup(name)
        end
        assert called(Persistent.get(name))
        assert {:error, "mocked error"} = Persistent.get(name)
      end
    end
  end

end
