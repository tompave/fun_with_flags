defmodule FunWithFlags.NotificationsTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Notifications


  describe "unique_id()" do
    test "it returns a string" do
      assert is_binary(Notifications.unique_id())
    end

    test "it always returns the same ID for the GenServer" do
      assert Notifications.unique_id() == Notifications.unique_id()
    end

    test "the ID changes if the GenServer restarts" do
      a = Notifications.unique_id()
      kill_process(Notifications)
      :timer.sleep(1)
      refute a == Notifications.unique_id()
    end
  end


  describe "payload_for(flag_name)" do
    test "it returns a 2 item list" do
      flag_name = unique_atom()

      output = Notifications.payload_for(flag_name)
      assert is_list(output)
      assert 2 == length(output)
    end

    test "the first one is the channel name, the second one is the flag
          name plus the unique_id for the GenServer" do
      flag_name = unique_atom()
      u_id = Notifications.unique_id()
      channel = "fun_with_flags_changes"

      assert [^channel, << blob :: binary >>] = Notifications.payload_for(flag_name)
      assert [^u_id, string] = String.split(blob, ":")
      assert ^flag_name = String.to_atom(string)
    end
  end


  test "it receives messages if something is published on Redis" do
    alias FunWithFlags.Store.Persistent

    u_id = Notifications.unique_id()
    channel = "fun_with_flags_changes"
    pubsub_receiver_pid = GenServer.whereis(:fun_with_flags_notifications)
    message = "foobar"

    with_mock(Notifications, [:passthrough], []) do
      Redix.command(Persistent, ["PUBLISH", channel, message])
      :timer.sleep(1)

      assert called(
        Notifications.handle_info(
          {
            :redix_pubsub,
            pubsub_receiver_pid,
            :message,
            %{channel: channel, payload: message}
          },
          u_id
        )
      )
    end
  end


  describe "integration: message handling" do
    alias FunWithFlags.Store.Persistent
    alias FunWithFlags.{Store, Config}


    test "when the message is not valid, it is ignored" do
      channel = "fun_with_flags_changes"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, "foobar"])
        :timer.sleep(30)
        refute called(Store.reload(:foobar))
      end
    end


    test "when the message comes from this same process, it is ignored" do
      u_id = Notifications.unique_id()
      channel = "fun_with_flags_changes"
      message = "#{u_id}:foobar"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, message])
        :timer.sleep(30)
        refute called(Store.reload(:foobar))
      end
    end


    test "when the message comes from another process, it reloads the flag" do
      another_u_id = Config.build_unique_id()
      refute another_u_id == Notifications.unique_id()

      channel = "fun_with_flags_changes"
      message = "#{another_u_id}:foobar"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, message])
        :timer.sleep(30)
        assert called(Store.reload(:foobar))
      end
    end
  end


  describe "integration: side effects" do
    alias FunWithFlags.Store.{Cache,Persistent}
    alias FunWithFlags.{Store, Config}

    setup do
      flag_name = unique_atom()
      {:ok, false} = Persistent.put(flag_name, false)
      :timer.sleep(10)
      {:ok, true} = Cache.put(flag_name, true)

      assert false == Persistent.get(flag_name)
      assert {:ok, true} = Cache.get(flag_name)

      {:ok, flag_name: flag_name}
    end


    test "when the message is not valid, the Cached value is not changed", %{flag_name: flag_name} do
      channel = "fun_with_flags_changes"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, to_string(flag_name)])
        :timer.sleep(30)
        assert {:ok, true} = Cache.get(flag_name)
      end
    end


    test "when the message comes from this same process, the Cached value is not changed", %{flag_name: flag_name} do
      u_id = Notifications.unique_id()
      channel = "fun_with_flags_changes"
      message = "#{u_id}:#{to_string(flag_name)}"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, message])
        :timer.sleep(30)
        assert {:ok, true} = Cache.get(flag_name)
      end
    end


    test "when the message comes from another process, the Cached value is reloaded", %{flag_name: flag_name} do
      another_u_id = Config.build_unique_id()
      refute another_u_id == Notifications.unique_id()

      channel = "fun_with_flags_changes"
      message = "#{another_u_id}:#{to_string(flag_name)}"
      
      with_mock(Store, [:passthrough], []) do
        Redix.command(Persistent, ["PUBLISH", channel, message])
        :timer.sleep(30)
        assert {:ok, false} = Cache.get(flag_name)
      end
    end
  end
end
