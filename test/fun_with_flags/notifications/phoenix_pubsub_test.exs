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

  describe "subscribed?()" do
    test "it returns true if the GenServer is subscribed to the pubsub topic" do
      assert :ok = GenServer.call(PubSub, {:test_helper_set_subscription_status, :subscribed})
      assert true = PubSub.subscribed?()

      # Kill the process to restore its normal state.
      kill_process(PubSub)
    end

    test "it returns false if the GenServer is not subscribed to the pubsub topic" do
      assert :ok = GenServer.call(PubSub, {:test_helper_set_subscription_status, :unsubscribed})
      assert false == PubSub.subscribed?()

      # Kill the process to restore its normal state.
      kill_process(PubSub)
    end
  end

  describe "publish_change(flag_name)" do
    setup do
      wait_until_pubsub_is_ready!()

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

        assert_with_retries(fn ->
          assert called(
            Phoenix.PubSub.broadcast!(
              :fwf_test,
              "fun_with_flags_changes",
              {:fwf_changes, {:updated, name, u_id}}
            )
          )
        end)
      end
    end

    test "causes other subscribers to receive a Phoenix.PubSub notification", %{name: name} do
      channel = "fun_with_flags_changes"
      u_id = PubSub.unique_id()

      :ok = Phoenix.PubSub.subscribe(:fwf_test, channel) # implicit self

      assert {:ok, _pid} = PubSub.publish_change(name)

      payload = {:updated, name, u_id}

      receive do
        {:fwf_changes, ^payload} -> :ok
      after
        500 -> flunk "Haven't received any message after 0.5 seconds"
      end

      # cleanup

      :ok = Phoenix.PubSub.unsubscribe(:fwf_test, channel) # implicit self
    end
  end


  test "it receives messages if something is published on Phoenix.PubSub" do
    u_id = PubSub.unique_id()
    client = FunWithFlags.Config.pubsub_client()
    channel = "fun_with_flags_changes"
    message = {:fwf_changes, {:updated, :foobar, u_id}}

    wait_until_pubsub_is_ready!()

    with_mock(PubSub, [:passthrough], []) do
      Phoenix.PubSub.broadcast!(client, channel, message)

      assert_with_retries(fn ->
        assert called(
          PubSub.handle_info(message, {u_id, :subscribed})
        )
      end)
    end
  end


  describe "integration: message handling" do
    alias FunWithFlags.{Store, Config}


    test "when the message comes from this same process, it is ignored" do
      u_id = PubSub.unique_id()
      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, :a_flag_name, u_id}}

      wait_until_pubsub_is_ready!()

      with_mock(Store, [:passthrough], []) do
        Phoenix.PubSub.broadcast!(client, channel, message)

        assert_with_retries(fn ->
          refute called(Store.reload(:a_flag_name))
        end)
      end
    end


    test "when the message comes from another process, it reloads the flag" do
      another_u_id = Config.build_unique_id()
      refute another_u_id == PubSub.unique_id()

      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, :a_flag_name, another_u_id}}

      wait_until_pubsub_is_ready!()

      with_mock(Store, [:passthrough], []) do
        Phoenix.PubSub.broadcast!(client, channel, message)

        assert_with_retries(fn ->
          assert called(Store.reload(:a_flag_name))
        end)
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

      {:ok, ^stored_flag} = Config.persistence_adapter.put(name, gate)
      assert_with_retries(fn ->
        {:ok, ^cached_flag} = Cache.put(cached_flag)
      end)

      assert {:ok, ^stored_flag} = Config.persistence_adapter.get(name)
      assert {:ok, ^cached_flag} = Cache.get(name)

      wait_until_pubsub_is_ready!()

      {:ok, name: name, stored_flag: stored_flag, cached_flag: cached_flag}
    end

    # This should be in `setup` but in there it produces a compiler warning because
    # the two variables will never match (duh).
    test "verify test setup", %{cached_flag: cached_flag, stored_flag: stored_flag} do
      refute match? ^stored_flag, cached_flag
    end


    test "when the message comes from this same process, the Cached value is not changed", %{name: name, cached_flag: cached_flag} do
      u_id = PubSub.unique_id()
      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, name, u_id}}

      Phoenix.PubSub.broadcast!(client, channel, message)

      assert_with_retries(fn ->
        assert {:ok, ^cached_flag} = Cache.get(name)
      end)
    end


    test "when the message comes from another process, the Cached value is reloaded", %{name: name, cached_flag: cached_flag, stored_flag: stored_flag} do
      another_u_id = Config.build_unique_id()
      refute another_u_id == PubSub.unique_id()

      client = FunWithFlags.Config.pubsub_client()
      channel = "fun_with_flags_changes"
      message = {:fwf_changes, {:updated, name, another_u_id}}

      assert {:ok, ^cached_flag} = Cache.get(name)
      Phoenix.PubSub.broadcast!(client, channel, message)

      assert_with_retries(fn ->
        assert {:ok, ^stored_flag} = Cache.get(name)
      end)
    end
  end
end
