defmodule FunWithFlags.Notifications.PhoenixPubSubTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Notifications.PhoenixPubSub, as: PubSub

  @moduletag :phoenix_pubsub

  describe "unique_id()" do
    test "it returns a string" do
      assert is_binary(PubSub.unique_id())
    end

    test "it always returns the same ID for the GenServer" do
      assert PubSub.unique_id() == PubSub.unique_id()
    end

    test "the ID changes if the GenServer restarts" do
      a = PubSub.unique_id()
      kill_process(PubSub)
      :timer.sleep(1)
      refute a == PubSub.unique_id()
    end
  end

  describe "publish_change(flag_name)" do
    setup do
      {:ok, name: unique_atom()}
    end

    test "returns a PID (it starts a Task)", %{name: name} do
      assert {:ok, pid} = PubSub.publish_change(name)
      assert is_pid(pid)
    end

    test "publishes a notification to Phoenix.PubSub", %{name: name} do
      u_id = PubSub.unique_id()

      with_mocks([
        {Phoenix.PubSub, [:passthrough], []}
      ]) do
        assert {:ok, _pid} = PubSub.publish_change(name)
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

    test "causes other subscribers to receive a Phoenix.PubSub notification", %{name: name} do
      channel = "fun_with_flags_changes"
      u_id = PubSub.unique_id()

      # implicit self
      :ok = Phoenix.PubSub.subscribe(:fwf_test, channel)

      assert {:ok, _pid} = PubSub.publish_change(name)

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
  end

  test "it receives messages if something is published on Phoenix.PubSub" do
    u_id = PubSub.unique_id()
    client = FunWithFlags.Config.pubsub_client()
    channel = "fun_with_flags_changes"
    message = {:fwf_changes, {:updated, :foobar, u_id}}

    with_mock(PubSub, [:passthrough], []) do
      Phoenix.PubSub.broadcast!(client, channel, message)

      :timer.sleep(1)

      assert called(PubSub.handle_info(message, u_id))
    end
  end

  describe "integration: message handling" do
    alias FunWithFlags.{Store, Config}

    test "when the message comes from this same process, it is ignored" do
      u_id = PubSub.unique_id()
      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, :a_flag_name, u_id}}

      with_mock(Store, [:passthrough], []) do
        Phoenix.PubSub.broadcast!(client, channel, message)
        :timer.sleep(30)
        refute called(Store.reload(:a_flag_name))
      end
    end

    test "when the message comes from another process, it reloads the flag" do
      another_u_id = Config.build_unique_id()
      refute another_u_id == PubSub.unique_id()

      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, :a_flag_name, another_u_id}}

      with_mock(Store, [:passthrough], []) do
        Phoenix.PubSub.broadcast!(client, channel, message)
        :timer.sleep(30)
        assert called(Store.reload(:a_flag_name))
      end
    end
  end

  describe "integration: side effects" do
    alias FunWithFlags.Store.Cache
    alias FunWithFlags.{Store, Config, Gate, Flag}

    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      stored_flag = %Flag{name: name, gates: [gate]}

      gate2 = %Gate{type: :boolean, enabled: false}
      cached_flag = %Flag{name: name, gates: [gate2]}

      {:ok, ^stored_flag} = Config.persistence_adapter().put(name, gate)
      :timer.sleep(10)
      {:ok, ^cached_flag} = Cache.put(cached_flag)

      assert {:ok, ^stored_flag} = Config.persistence_adapter().get(name)
      assert {:ok, ^cached_flag} = Cache.get(name)

      refute match?(^stored_flag, cached_flag)

      {:ok, name: name, stored_flag: stored_flag, cached_flag: cached_flag}
    end

    test "when the message comes from this same process, the Cached value is not changed", %{
      name: name,
      cached_flag: cached_flag
    } do
      u_id = PubSub.unique_id()
      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, name, u_id}}

      Phoenix.PubSub.broadcast!(client, channel, message)
      :timer.sleep(30)
      assert {:ok, ^cached_flag} = Cache.get(name)
    end

    test "when the message comes from another process, the Cached value is reloaded", %{
      name: name,
      cached_flag: cached_flag,
      stored_flag: stored_flag
    } do
      another_u_id = Config.build_unique_id()
      refute another_u_id == PubSub.unique_id()

      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, name, another_u_id}}

      assert {:ok, ^cached_flag} = Cache.get(name)
      Phoenix.PubSub.broadcast!(client, channel, message)
      :timer.sleep(30)
      assert {:ok, ^stored_flag} = Cache.get(name)
    end
  end
end
