defmodule FunWithFlags.Store.PersistentTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Store.Persistent

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end


  describe "put(flag_name, value)" do
    test "put() can change the value of a flag" do
      flag_name = unique_atom()

      assert false == Persistent.get(flag_name)
      Persistent.put(flag_name, true)
      assert true == Persistent.get(flag_name)
      Persistent.put(flag_name, false)
      assert false == Persistent.get(flag_name)
    end

    test "put() returns the tuple {:ok, a_boolean_value}" do
      flag_name = unique_atom()
      assert {:ok, true} == Persistent.put(flag_name, true)
      assert {:ok, false} == Persistent.put(flag_name, false)
    end

    test "when the cache is enabled, put() will publish a notification to Redis" do
      assert true == FunWithFlags.Config.cache?
      flag_name = unique_atom()

      with_mocks([
        {FunWithFlags.Notifications, [], [
          payload_for: fn(name) ->
            ["fun_with_flags_changes", "unique_id_foobar:#{name}"]
          end,
          handle_info: fn(payload, state) ->
            :meck.passthrough([payload, state])
          end
        ]},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, true} = Persistent.put(flag_name, true)
        :timer.sleep(10)
        assert called FunWithFlags.Notifications.payload_for(flag_name)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{flag_name}"]
          )
        )
      end
    end

    test "when the cache is NOT enabled, put() will publish a notification to Redis" do
      flag_name = unique_atom()

      with_mocks([
        {FunWithFlags.Config, [], [cache?: fn() -> false end]},
        {FunWithFlags.Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, true} = Persistent.put(flag_name, true)
        :timer.sleep(10)
        refute called FunWithFlags.Notifications.payload_for(flag_name)

        refute called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{flag_name}"]
          )
        )
      end
    end
  end


  describe "get(flag_name)" do
    test "looking up an undefined flag returns false" do
      flag_name = unique_atom()
      assert false == Persistent.get(flag_name)
    end

    test "get() returns a boolean" do
      flag_name = unique_atom()
      assert false == Persistent.get(flag_name)
      Persistent.put(flag_name, true)
      assert true == Persistent.get(flag_name)
    end  
  end
  

  describe "unit: enable and disable with this module's API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      Persistent.put(flag_name, false)
      assert false == Persistent.get(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      Persistent.put(flag_name, true)
      assert true == Persistent.get(flag_name)
    end
  end

  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == Persistent.get(flag_name)
    end
  
    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == Persistent.get(flag_name)
    end
  end
end
