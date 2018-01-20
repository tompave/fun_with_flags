defmodule FunWithFlags.Store.Persistent.EctoTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Store.Persistent.Ecto, as: PersiEcto
  alias FunWithFlags.{Config, Flag, Gate}
  alias FunWithFlags.Notifications.PhoenixPubSub, as: NotifiPhoenix

  @moduletag :ecto_persistence

  describe "put(flag_name, %Gate{})" do
    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      flag = %Flag{name: name, gates: [gate]}
      {:ok, name: name, gate: gate, flag: flag}
    end

    test "put() can change the value of a flag", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)

      PersiEcto.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}} = PersiEcto.get(name)

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      PersiEcto.put(name, other_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_bool_gate]}} = PersiEcto.get(name)
      refute match?({:ok, %Flag{name: ^name, gates: [^first_bool_gate]}}, PersiEcto.get(name))

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      PersiEcto.put(name, actor_gate)

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^other_bool_gate]}} =
               PersiEcto.get(name)

      PersiEcto.put(name, first_bool_gate)

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^first_bool_gate]}} =
               PersiEcto.get(name)
    end

    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = PersiEcto.put(name, gate)
      assert {:ok, ^flag} = PersiEcto.put(name, gate)
    end

    test "put()'ing more gates will return an increasily updated flag", %{name: name, gate: gate} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = PersiEcto.put(name, gate)

      other_gate = %Gate{type: :actor, for: "string:asdf", enabled: true}

      assert {:ok, %Flag{name: ^name, gates: [^other_gate, ^gate]}} =
               PersiEcto.put(name, other_gate)
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, put() will publish a notification to Phoenix.PubSub",
         %{name: name, gate: gate, flag: flag} do
      assert Config.change_notifications_enabled?()

      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, ^flag} = PersiEcto.put(name, gate)
        :timer.sleep(10)

        assert called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
                 )
               )
      end
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, put() will cause other subscribers to receive a Phoenix.PubSub notification",
         %{name: name, gate: gate, flag: flag} do
      assert Config.change_notifications_enabled?()
      channel = "fun_with_flags_changes"
      u_id = NotifiPhoenix.unique_id()

      # Subscribe to the notifications

      # implicit self
      :ok = Phoenix.PubSub.subscribe(:fwf_test, channel)

      assert {:ok, ^flag} = PersiEcto.put(name, gate)

      payload = {:updated, name, u_id}

      receive do
        {:fwf_changes, ^payload} -> :ok
      after
        500 -> flunk("Haven't received any message after 0.5 seconds")
      end

      # cleanup

      # implicit self
      :ok = Phoenix.PubSub.unsubscribe(:fwf_test, channel)
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are NOT enabled, put() will NOT publish a notification to Phoenix.PubSub",
         %{name: name, gate: gate, flag: flag} do
      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Config, [], [change_notifications_enabled?: fn -> false end]},
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, ^flag} = PersiEcto.put(name, gate)
        :timer.sleep(10)

        refute called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
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
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate])}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, ^flag} = PersiEcto.put(name, actor_gate)
      {:ok, ^flag} = PersiEcto.get(name)

      {:ok,
       name: name,
       flag: flag,
       bool_gate: bool_gate,
       group_gate: group_gate,
       actor_gate: actor_gate}
    end

    test "delete(flag_name, gate) can change the value of a flag", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end

    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} =
               PersiEcto.delete(name, actor_gate)
    end

    test "deleting()'ing more gates will return an increasily simpler flag", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} =
               PersiEcto.delete(name, actor_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name, bool_gate)
    end

    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} =
               PersiEcto.delete(name, actor_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} =
               PersiEcto.delete(name, actor_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)

      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} =
               PersiEcto.delete(name, %Gate{
                 type: :actor,
                 for: "I'm not really there",
                 enabled: false
               })
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, delete(flag_name, gate) will publish a notification to PhoenixPubSub",
         %{name: name, group_gate: group_gate} do
      assert Config.change_notifications_enabled?()

      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, %Flag{name: ^name}} = PersiEcto.delete(name, group_gate)
        :timer.sleep(10)

        assert called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
                 )
               )
      end
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, delete(flag_name, gate) will cause other subscribers to receive a Phoenix.PubSub notification",
         %{name: name, group_gate: group_gate} do
      assert Config.change_notifications_enabled?()
      channel = "fun_with_flags_changes"
      u_id = NotifiPhoenix.unique_id()

      # Subscribe to the notifications

      # implicit self
      :ok = Phoenix.PubSub.subscribe(:fwf_test, channel)

      assert {:ok, %Flag{name: ^name}} = PersiEcto.delete(name, group_gate)

      payload = {:updated, name, u_id}

      receive do
        {:fwf_changes, ^payload} -> :ok
      after
        500 -> flunk("Haven't received any message after 0.5 seconds")
      end

      # cleanup

      # implicit self
      :ok = Phoenix.PubSub.unsubscribe(:fwf_test, channel)
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are NOT enabled, delete(flag_name, gate) will NOT publish a notification to Phoenix.PubSub ",
         %{name: name, group_gate: group_gate} do
      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Config, [], [change_notifications_enabled?: fn -> false end]},
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, %Flag{name: ^name}} = PersiEcto.delete(name, group_gate)
        :timer.sleep(10)

        refute called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
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
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate])}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, ^flag} = PersiEcto.put(name, actor_gate)
      {:ok, ^flag} = PersiEcto.get(name)

      {:ok,
       name: name,
       flag: flag,
       bool_gate: bool_gate,
       group_gate: group_gate,
       actor_gate: actor_gate}
    end

    test "delete(flag_name) will remove the flag from Redis (it will appear as an empty flag, which is the default when
          getting unknown flag name)", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end

    test "delete(flag_name) returns the tuple {:ok, %Flag{}}", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
    end

    test "deleting()'ing the same flag multiple time is a no-op. In other words: deleting a flag is idempotent
          and it's safe to try and delete non-present flags without errors", %{
      name: name,
      bool_gate: bool_gate,
      group_gate: group_gate,
      actor_gate: actor_gate
    } do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} =
               PersiEcto.get(name)

      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, delete(flag_name) will publish a notification to Phoenix.PubSub",
         %{name: name} do
      assert Config.change_notifications_enabled?()

      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
        :timer.sleep(10)

        assert called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
                 )
               )
      end
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are enabled, delete(flag_name) will cause other subscribers to receive a Phoenix.PubSub notification",
         %{name: name} do
      assert Config.change_notifications_enabled?()
      channel = "fun_with_flags_changes"
      u_id = NotifiPhoenix.unique_id()

      # Subscribe to the notifications

      # implicit self
      :ok = Phoenix.PubSub.subscribe(:fwf_test, channel)

      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)

      payload = {:updated, name, u_id}

      receive do
        {:fwf_changes, ^payload} -> :ok
      after
        500 -> flunk("Haven't received any message after 0.5 seconds")
      end

      # cleanup

      # implicit self
      :ok = Phoenix.PubSub.unsubscribe(:fwf_test, channel)
    end

    @tag phoenix_pubsub: "with_ecto"
    test "when change notifications are NOT enabled, delete(flag_name) will NOT publish a notification to Phoenix.PubSub",
         %{name: name} do
      u_id = NotifiPhoenix.unique_id()

      with_mocks [
        {Config, [], [change_notifications_enabled?: fn -> false end]},
        {Phoenix.PubSub, [:passthrough], []}
      ] do
        assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
        :timer.sleep(10)

        refute called(
                 Phoenix.PubSub.broadcast!(
                   :fwf_test,
                   "fun_with_flags_changes",
                   {:fwf_changes, {:updated, name, u_id}}
                 )
               )
      end
    end
  end

  # -------------

  describe "get(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
      PersiEcto.put(name, gate)
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = PersiEcto.get(name)
    end
  end

  describe "all_flags() returns the tuple {:ok, list} with all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = PersiEcto.all_flags()
    end

    test "with saved flags it returns a list of flags" do
      name1 = unique_atom()
      g_1a = Gate.new(:actor, "the actor", true)
      g_1b = Gate.new(:boolean, false)
      g_1c = Gate.new(:group, :horses, true)
      PersiEcto.put(name1, g_1a)
      PersiEcto.put(name1, g_1b)
      PersiEcto.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:actor, "another actor", true)
      g_2b = Gate.new(:boolean, false)
      PersiEcto.put(name2, g_2a)
      PersiEcto.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      PersiEcto.put(name3, g_3a)

      {:ok, result} = PersiEcto.all_flags()
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

  describe "all_flag_names() returns the tuple {:ok, list}, with the names of all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = PersiEcto.all_flag_names()
    end

    test "with saved flags it returns a list of flag names" do
      name1 = unique_atom()
      g_1a = Gate.new(:boolean, false)
      g_1b = Gate.new(:actor, "the actor", true)
      g_1c = Gate.new(:group, :horses, true)
      PersiEcto.put(name1, g_1a)
      PersiEcto.put(name1, g_1b)
      PersiEcto.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:boolean, false)
      g_2b = Gate.new(:actor, "another actor", true)
      PersiEcto.put(name2, g_2a)
      PersiEcto.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      PersiEcto.put(name3, g_3a)

      {:ok, result} = PersiEcto.all_flag_names()
      assert 3 = length(result)

      for name <- [name1, name2, name3] do
        assert name in result
      end
    end
  end

  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)

      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} =
               PersiEcto.get(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)

      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} =
               PersiEcto.get(name)
    end
  end

  defp sort_gates(gates) do
    Enum.sort_by(gates, & &1.type)
  end
end
