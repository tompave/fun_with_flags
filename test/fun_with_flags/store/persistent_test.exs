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
    alias FunWithFlags.{Config, Notifications}

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
      assert true == Config.cache?
      flag_name = unique_atom()

      with_mocks([
        {Notifications, [], [
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
        assert called Notifications.payload_for(flag_name)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{flag_name}"]
          )
        )
      end
    end


    test "when the cache is enabled, put() will cause other subscribers to receive a Redis notification" do
      assert true == Config.cache?
      flag_name = unique_atom()
      channel = "fun_with_flags_changes"
      u_id = Notifications.unique_id()

      # Subscribe to the notifications

      {:ok, receiver} = Redix.PubSub.start_link(Config.redis_config, [sync_connect: true])
      :ok = Redix.PubSub.subscribe(receiver, channel, self())

      receive do
        {:redix_pubsub, ^receiver, :subscribed, %{channel: ^channel}} -> :ok
      after
        500 -> flunk "Subscribe didn't work"
      end

      assert {:ok, true} = Persistent.put(flag_name, true)

      payload = "#{u_id}:#{to_string(flag_name)}"
      
      receive do
        {:redix_pubsub, ^receiver, :message, %{channel: ^channel, payload: ^payload}} -> :ok
      after
        500 -> flunk "Haven't received any message after 0.5 seconds"
      end

      # cleanup

      Redix.PubSub.unsubscribe(receiver, channel, self())

      receive do
        {:redix_pubsub, ^receiver, :unsubscribed, %{channel: ^channel}} -> :ok
      after
        500 -> flunk "Unsubscribe didn't work"
      end

      Process.exit(receiver, :kill)
    end


    test "when the cache is NOT enabled, put() will publish a notification to Redis" do
      flag_name = unique_atom()

      with_mocks([
        {Config, [], [cache?: fn() -> false end]},
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, true} = Persistent.put(flag_name, true)
        :timer.sleep(10)
        refute called Notifications.payload_for(flag_name)

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
