defmodule FunWithFlags.Store.PersistentTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Store.Persistent
  alias FunWithFlags.{Config, Notifications, Flag, Gate}

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end


  describe "put(flag_name, %Gate{})" do
    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      flag = %Flag{name: name, gates: [gate]}
      {:ok, name: name, gate: gate, flag: flag}
    end


    test "put() can change the value of a flag", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)

      Persistent.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}} = Persistent.get(name)

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      Persistent.put(name, other_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_bool_gate]}} = Persistent.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}}, Persistent.get(name)

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      Persistent.put(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_bool_gate, ^actor_gate]}} = Persistent.get(name)

      Persistent.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_bool_gate, ^actor_gate]}} = Persistent.get(name)
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = Persistent.put(name, gate)
      assert {:ok, ^flag} = Persistent.put(name, gate)
    end

    test "put()'ing more gates will return an increasily updated flag", %{name: name, gate: gate} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = Persistent.put(name, gate)

      other_gate = %Gate{type: :actor, for: "string:asdf", enabled: true}
      assert {:ok, %Flag{name: ^name, gates: [^gate, ^other_gate]}} = Persistent.put(name, other_gate)
    end


    test "when the cache is enabled, put() will publish a notification to Redis", %{name: name, gate: gate, flag: flag} do
      assert true == Config.cache?

      u_id = Notifications.unique_id()

      with_mocks([
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, ^flag} = Persistent.put(name, gate)
        :timer.sleep(10)
        assert called Notifications.payload_for(name)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "#{u_id}:#{name}"]
          )
        )
      end
    end


    test "when the cache is enabled, put() will cause other subscribers to receive a Redis notification", %{name: name, gate: gate, flag: flag} do
      assert true == Config.cache?
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

      assert {:ok, ^flag} = Persistent.put(name, gate)

      payload = "#{u_id}:#{to_string(name)}"
      
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


    test "when the cache is NOT enabled, put() will NOT publish a notification to Redis", %{name: name, gate: gate, flag: flag} do
      with_mocks([
        {Config, [], [cache?: fn() -> false end]},
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, ^flag} = Persistent.put(name, gate)
        :timer.sleep(10)
        refute called Notifications.payload_for(name)

        refute called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{name}"]
          )
        )
      end
    end
  end

# -----------------

  describe "delete(flag_name, %Gate{})" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: :admins, enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: [bool_gate, group_gate, actor_gate]}

      {:ok, %Flag{name: ^name}} = Persistent.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = Persistent.put(name, group_gate)
      {:ok, ^flag} = Persistent.put(name, actor_gate)
      {:ok, ^flag} = Persistent.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate}
    end


    test "delete(flag_name, gate) can change the value of a flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)

      Persistent.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^actor_gate]}} = Persistent.get(name)

      Persistent.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate]}} = Persistent.get(name)

      Persistent.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.delete(name, actor_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name, bool_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = Persistent.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = Persistent.delete(name, %Gate{type: :actor, for: "I'm not really there", enabled: false})
    end


    test "when the cache is enabled, delete(flag_name, gate) will publish a notification to Redis", %{name: name, group_gate: group_gate} do
      assert true == Config.cache?

      u_id = Notifications.unique_id()

      with_mocks([
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, %Flag{name: ^name}} = Persistent.delete(name, group_gate)
        :timer.sleep(10)
        assert called Notifications.payload_for(name)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "#{u_id}:#{name}"]
          )
        )
      end
    end


    test "when the cache is enabled, delete(flag_name, gate) will cause other subscribers to receive a Redis notification", %{name: name, group_gate: group_gate} do
      assert true == Config.cache?
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

      assert {:ok, %Flag{name: ^name}} = Persistent.delete(name, group_gate)

      payload = "#{u_id}:#{to_string(name)}"
      
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


    test "when the cache is NOT enabled, delete(flag_name, gate) will NOT publish a notification to Redis", %{name: name, group_gate: group_gate} do
      with_mocks([
        {Config, [], [cache?: fn() -> false end]},
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, %Flag{name: ^name}} = Persistent.delete(name, group_gate)
        :timer.sleep(10)
        refute called Notifications.payload_for(name)

        refute called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{name}"]
          )
        )
      end
    end
  end

# -----------------


  describe "delete(flag_name)" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: :admins, enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: [bool_gate, group_gate, actor_gate]}

      {:ok, %Flag{name: ^name}} = Persistent.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = Persistent.put(name, group_gate)
      {:ok, ^flag} = Persistent.put(name, actor_gate)
      {:ok, ^flag} = Persistent.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate}
    end


    test "delete(flag_name) will remove the flag from Redis (it will appear as an empty flag, which is the default when
          getting unknown flag name)", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)

      Persistent.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
    end


    test "delete(flag_name) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
    end


    test "deleting()'ing the same flag multiple time is a no-op. In other words: deleting a flag is idempotent
          and it's safe to try and delete non-present flags without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^actor_gate]}} = Persistent.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
    end


    test "when the cache is enabled, delete(flag_name) will publish a notification to Redis", %{name: name} do
      assert true == Config.cache?

      u_id = Notifications.unique_id()

      with_mocks([
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
        :timer.sleep(10)
        assert called Notifications.payload_for(name)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "#{u_id}:#{name}"]
          )
        )
      end
    end


    test "when the cache is enabled, delete(flag_name) will cause other subscribers to receive a Redis notification", %{name: name} do
      assert true == Config.cache?
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

      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)

      payload = "#{u_id}:#{to_string(name)}"
      
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


    test "when the cache is NOT enabled, delete(flag_name) will NOT publish a notification to Redis", %{name: name} do
      with_mocks([
        {Config, [], [cache?: fn() -> false end]},
        {Notifications, [:passthrough], []},
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.delete(name)
        :timer.sleep(10)
        refute called Notifications.payload_for(name)

        refute called(
          Redix.command(
            FunWithFlags.Store.Persistent,
            ["PUBLISH", "fun_with_flags_changes", "unique_id_foobar:#{name}"]
          )
        )
      end
    end
  end

# -------------

  describe "get(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert {:ok, %Flag{name: ^name, gates: []}} = Persistent.get(name)
      Persistent.put(name, gate)
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = Persistent.get(name)
    end  
  end
  


  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = Persistent.get(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = Persistent.get(name)
    end
  end
end
