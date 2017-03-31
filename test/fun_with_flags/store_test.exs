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
      assert {:ok, %Flag{name: ^flag_name, gates: []}} = Store.lookup(flag_name)
    end

    test "looking up a defined flag returns the flag", %{name: name, gate: gate, flag: flag} do
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.lookup(name)
      Store.put(name, gate)
      assert {:ok, ^flag} = Store.lookup(name)
    end
  end


  describe "put(flag_name, gate)" do
    test "put() can change the value of a flag", %{name: name, gate: gate, flag: flag} do
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.lookup(name)

      Store.put(name, gate)
      assert {:ok, ^flag} = Store.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      Store.put(name, gate2)
      assert {:ok, %Flag{name: ^name, gates: [^gate2]}} = Store.lookup(name)
      refute match? ^flag, Store.lookup(name)
    end

    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, ^flag} = Store.put(name, gate)
    end
  end


  describe "delete(flag_name, gate)" do
    setup data do
      group_gate = %Gate{type: :group, for: :muggles, enabled: false}
      bool_gate = data[:gate]
      name = data[:name]

      Store.put(name, bool_gate)
      Store.put(name, group_gate)
      {:ok, flag} = Store.lookup(name)
      assert %Flag{name: ^name, gates: [^bool_gate, ^group_gate]} = flag

      {:ok, bool_gate: bool_gate, group_gate: group_gate}
    end

    test "delete(flag_name, gate) can change the value of a flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Store.lookup(name)

      Store.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = Store.lookup(name)
      Store.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.lookup(name)
    end

    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = Store.delete(name, bool_gate)
    end

    test "deleting is safe and idempotent", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = Store.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = Store.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.delete(name, group_gate)
    end
  end


  describe "delete(flag_name)" do
    setup data do
      group_gate = %Gate{type: :group, for: :muggles, enabled: false}
      bool_gate = data[:gate]
      name = data[:name]

      Store.put(name, bool_gate)
      Store.put(name, group_gate)
      {:ok, flag} = Store.lookup(name)
      assert %Flag{name: ^name, gates: [^bool_gate, ^group_gate]} = flag

      {:ok, bool_gate: bool_gate, group_gate: group_gate}
    end

    test "delete(flag_name) will reset all the flag gates", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Store.lookup(name)

      Store.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.lookup(name)
    end

    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name} do
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.delete(name)
    end

    test "deleting is safe and idempotent", %{name: name} do
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Store.delete(name)
    end
  end


  describe "reload(flag_name) reads the flag value from Redis and updates the Cache" do
    test "if the flag is not found in Redis, it sets it to false in the Cache", %{name: name, flag: flag} do
      empty_flag = %Flag{name: name, gates: []}
      assert {:ok, ^empty_flag} = Persistent.get(name)
      assert {:miss, :not_found, nil} = Cache.get(name)
      assert {:ok, ^empty_flag} = Store.lookup(name)

      Cache.put(flag)
      assert {:ok, ^flag} = Cache.get(name)
      assert {:ok, ^flag} = Store.lookup(name)

      Store.reload(name)

      assert {:ok, ^empty_flag} = Cache.get(name)
      assert {:ok, ^empty_flag} = Store.lookup(name)
    end



    test "if the flag is stored in Redis, it stores it in the Cache", %{name: name, gate: gate, flag: flag} do
      {:ok, ^flag} = Persistent.put(name, gate)
      assert {:ok, ^flag} = Persistent.get(name)

      gate2 = %Gate{gate | enabled: false}
      flag2 = %Flag{name: name, gates: [gate2]}

      Cache.put(flag2)
      assert {:ok, ^flag2} = Cache.get(name)
      assert {:ok, ^flag2} = Store.lookup(name)
      refute match? {:ok, ^flag}, Store.lookup(name)

      Store.reload(name)

      assert {:ok, ^flag} = Cache.get(name)
      assert {:ok, ^flag} = Store.lookup(name)
      refute match? {:ok, ^flag2}, Store.lookup(name)
    end
  end


  describe "all_flags() returns all the flags" do
    test "with no saved flags it returns an empty list" do
      clear_redis_test_db()
      assert [] = Store.all_flags()
    end

    test "with saved flags in returns a list of flags" do
      clear_redis_test_db()

      name1 = unique_atom()
      g_1a = Gate.new(:boolean, false)
      g_1b = Gate.new(:actor, "the actor", true)
      g_1c = Gate.new(:group, :horses, true)
      Store.put(name1, g_1a)
      Store.put(name1, g_1b)
      Store.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:boolean, false)
      g_2b = Gate.new(:actor, "another actor", true)
      Store.put(name2, g_2a)
      Store.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      Store.put(name3, g_3a)

      result = Store.all_flags()
      assert 3 = length(result)

      for flag <- [
        %Flag{name: name1, gates: [g_1a, g_1b, g_1c]},
        %Flag{name: name2, gates: [g_2a, g_2b]},
        %Flag{name: name3, gates: [g_3a]}
      ] do
        assert flag in result
      end
    end
  end


  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = Store.lookup(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = Store.lookup(name)
    end
  end


  describe "integration: Cache and Persistence" do
    setup data do
      group_gate = %Gate{type: :group, for: :muggles, enabled: false}
      bool_gate = data[:gate]
      {:ok, bool_gate: bool_gate, group_gate: group_gate}
    end


    test "if we have a Cached value, the Persistent store is not touched at all", %{name: name, flag: flag} do
      Cache.put(flag)

      with_mocks([
        {Persistent, [:passthrough], []},
        {Cache, [:passthrough], []}
      ]) do
        assert {:ok, ^flag} = Store.lookup(name)
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

    test "deleting a gate will update both the cache and the persistent store", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      Store.put(name, bool_gate)
      Store.put(name, group_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.get(name)

      Store.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.get(name)

      # repeat. check it's safe and idempotent
      Store.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.get(name)

      Store.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
    end


    test "deleting a flag will reset both the cache and the persistent store", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      Store.put(name, bool_gate)
      Store.put(name, group_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.get(name)

      Store.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)

      # repeat. check it's safe and idempotent
      Store.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Cache.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
    end


    test "when the value is initially not in the cache but set in redis,
          looking it up will populate the cache", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)

      assert {:miss, :not_found, nil} = Cache.get(name)
      assert {:ok, ^flag} = Persistent.get(name)
      
      assert {:ok, ^flag} = Store.lookup(name)
      assert {:ok, ^flag} = Cache.get(name)
    end


    test "when the value is initially not in the cache and not in redis,
          looking it up will populate the cache", %{name: name} do
      empty_flag = %Flag{name: name, gates: []}

      assert {:miss, :not_found, nil} == Cache.get(name)
      assert {:ok, ^empty_flag} = Persistent.get(name)

      assert {:ok, ^empty_flag} = Store.lookup(name)
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

      assert {:ok, ^flag} = Store.lookup(name)
      assert {:ok, ^flag} = Cache.get(name)

      timetravel by: (Config.cache_ttl + 1) do
        assert {:miss, :expired, ^flag} = Cache.get(name)
        assert {:ok, ^flag} = Store.lookup(name)
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
        assert {:ok, ^flag} = Store.lookup(name)
        assert called(Cache.get(name))
        refute called(Persistent.get(name))
      end
    end


    test "if the Cached value is expired, it will still be used", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)
      assert {:ok, ^flag} = Store.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      flag2 = %Flag{name: name, gates: [gate2]}

      Cache.put(flag2)
      assert {:ok, ^flag2} = Cache.get(name)

      timetravel by: (Config.cache_ttl + 1) do
        with_mock(Persistent, [], get: fn(^name) -> {:error, "mocked error"} end) do
          assert {:ok, ^flag2} = Store.lookup(name)
          assert {:miss, :expired, ^flag2} = Cache.get(name)
          assert called(Persistent.get(name))
          assert {:error, "mocked error"} = Persistent.get(name)
        end
      end
    end


    test "if there is no cached value, it raises an error", %{name: name, gate: gate, flag: flag} do
      Persistent.put(name, gate)
      assert {:ok, ^flag} = Store.lookup(name)

      Cache.flush()
      assert {:miss, :not_found, nil} = Cache.get(name)

      with_mock(Persistent, [], get: fn(^name) -> {:error, "mocked error"} end) do
        assert_raise RuntimeError, "Can't load feature flag '#{name}' from neither Redis nor the cache", fn() ->
          Store.lookup(name)
        end
        assert called(Persistent.get(name))
        assert {:error, "mocked error"} = Persistent.get(name)
      end
    end
  end

end
