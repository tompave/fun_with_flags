defmodule FunWithFlags.Notifications.RedisTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.Notifications.Redis, as: NotifiRedis

  @moduletag :redis_pubsub

  describe "worker_spec" do
    setup do
      # Before each test ensure that the initial config is the default one.
      ensure_default_redis_config_in_app_env()

      # Cleanup
      on_exit(&reset_app_env_to_default_redis_config/0)
      :ok
    end

    test "when the Redis config is a URL string" do
      url = "redis:://1.2.3.4:5678/42"
      configure_redis_with(url)

      expected = %{
        id: FunWithFlags.Notifications.Redis,
        start: {
          FunWithFlags.Notifications.Redis,
          :start_link,
          [
            {url, name: :fun_with_flags_notifications, sync_connect: false}
          ]
        },
        type: :worker,
        restart: :permanent
      }

      assert ^expected = NotifiRedis.worker_spec()
    end

    test "when the Redis config is a {URL, opts} tuple" do
      url = "redis:://1.2.3.4:5678/42"
      opts = [socket_opts: [:inet6]]
      configure_redis_with({url, opts})

      expected = %{
        id: FunWithFlags.Notifications.Redis,
        start: {
          FunWithFlags.Notifications.Redis,
          :start_link,
          [
            {
              url,
              [
                socket_opts: [:inet6],
                name: :fun_with_flags_notifications,
                sync_connect: false
              ]
            }
          ]
        },
        type: :worker,
        restart: :permanent
      }

      assert ^expected = NotifiRedis.worker_spec()
    end

    test "when the Redis config is keyword list" do
      kw = [database: 100, port: 2000]
      configure_redis_with(kw)

      expected = %{
        id: FunWithFlags.Notifications.Redis,
        start: {
          FunWithFlags.Notifications.Redis,
          :start_link,
          [
            [
              host: "localhost",
              database: 100,
              port: 2000,
              name: :fun_with_flags_notifications,
              sync_connect: false
            ]
          ]
        },
        type: :worker,
        restart: :permanent
      }

      assert ^expected = NotifiRedis.worker_spec()
    end
  end

  describe "unique_id()" do
    test "it returns a string" do
      assert is_binary(NotifiRedis.unique_id())
    end

    test "it always returns the same ID for the GenServer" do
      assert NotifiRedis.unique_id() == NotifiRedis.unique_id()
    end

    test "the ID changes if the GenServer restarts" do
      a = NotifiRedis.unique_id()
      kill_process(NotifiRedis)
      :timer.sleep(1)
      refute a == NotifiRedis.unique_id()
    end
  end


  describe "payload_for(flag_name)" do
    test "it returns a 2 item list" do
      flag_name = unique_atom()

      output = NotifiRedis.payload_for(flag_name)
      assert is_list(output)
      assert 2 == length(output)
    end

    test "the first one is the channel name, the second one is the flag
          name plus the unique_id for the GenServer" do
      flag_name = unique_atom()
      u_id = NotifiRedis.unique_id()
      channel = "fun_with_flags_changes"

      assert [^channel, << blob :: binary >>] = NotifiRedis.payload_for(flag_name)
      assert [^u_id, string] = String.split(blob, ":")
      assert ^flag_name = String.to_atom(string)
    end
  end


  describe "publish_change(flag_name)" do
    setup do
      {:ok, name: unique_atom()}
    end

    test "returns a PID (it starts a Task)", %{name: name} do
      assert {:ok, pid} = NotifiRedis.publish_change(name)
      assert is_pid(pid)
    end

    test "publishes a notification to Redis", %{name: name} do
      u_id = NotifiRedis.unique_id()

      with_mocks([
        {Redix, [:passthrough], []}
      ]) do
        assert {:ok, _pid} = NotifiRedis.publish_change(name)
        :timer.sleep(10)

        assert called(
          Redix.command(
            FunWithFlags.Store.Persistent.Redis,
            ["PUBLISH", "fun_with_flags_changes", "#{u_id}:#{name}"]
          )
        )
      end
    end

    test "causes other subscribers to receive a Redis notification", %{name: name} do
      channel = "fun_with_flags_changes"
      u_id = NotifiRedis.unique_id()

      {:ok, receiver} = Redix.PubSub.start_link(Keyword.merge(FunWithFlags.Config.redis_config, [sync_connect: true]))
      {:ok, ref} = Redix.PubSub.subscribe(receiver, channel, self())

      receive do
        {:redix_pubsub, ^receiver, ^ref, :subscribed, %{channel: ^channel}} -> :ok
      after
        500 -> flunk "Subscribe didn't work"
      end

      assert {:ok, _pid} = NotifiRedis.publish_change(name)

      payload = "#{u_id}:#{to_string(name)}"

      receive do
        {:redix_pubsub, ^receiver, ^ref, :message, %{channel: ^channel, payload: ^payload}} -> :ok
      after
        500 -> flunk "Haven't received any message after 0.5 seconds"
      end

      # cleanup

      Redix.PubSub.unsubscribe(receiver, channel, self())

      receive do
        {:redix_pubsub, ^receiver, ^ref, :unsubscribed, %{channel: ^channel}} -> :ok
      after
        500 -> flunk "Unsubscribe didn't work"
      end

      Process.exit(receiver, :kill)
    end
  end


  test "it receives messages if something is published on Redis" do
    alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis

    u_id = NotifiRedis.unique_id()
    channel = "fun_with_flags_changes"
    pubsub_receiver_pid = GenServer.whereis(:fun_with_flags_notifications)
    message = "foobar"

    {^u_id, ref} = :sys.get_state(FunWithFlags.Notifications.Redis)

    with_mock(NotifiRedis, [:passthrough], []) do
      Redix.command(PersiRedis, ["PUBLISH", channel, message])
      :timer.sleep(1)

      assert called(
        NotifiRedis.handle_info(
          {
            :redix_pubsub,
            pubsub_receiver_pid,
            ref,
            :message,
            %{channel: channel, payload: message}
          },
          {u_id, ref}
        )
      )
    end
  end


  describe "integration: message handling" do
    alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis
    alias FunWithFlags.{Store, Config}


    test "when the message is not valid, it is ignored" do
      channel = "fun_with_flags_changes"

      with_mock(Store, [:passthrough], []) do
        Redix.command(PersiRedis, ["PUBLISH", channel, "foobar"])
        :timer.sleep(30)
        refute called(Store.reload(:foobar))
      end
    end


    test "when the message comes from this same process, it is ignored" do
      u_id = NotifiRedis.unique_id()
      channel = "fun_with_flags_changes"
      message = "#{u_id}:foobar"

      with_mock(Store, [:passthrough], []) do
        Redix.command(PersiRedis, ["PUBLISH", channel, message])
        :timer.sleep(30)
        refute called(Store.reload(:foobar))
      end
    end


    test "when the message comes from another process, it reloads the flag" do
      another_u_id = Config.build_unique_id()
      refute another_u_id == NotifiRedis.unique_id()

      channel = "fun_with_flags_changes"
      message = "#{another_u_id}:foobar"

      with_mock(Store, [:passthrough], []) do
        Redix.command(PersiRedis, ["PUBLISH", channel, message])
        :timer.sleep(30)
        assert called(Store.reload(:foobar))
      end
    end
  end


  describe "integration: side effects" do
    alias FunWithFlags.Store.Cache
    alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis
    alias FunWithFlags.{Store, Config, Gate, Flag}

    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      stored_flag = %Flag{name: name, gates: [gate]}

      gate2 = %Gate{type: :boolean, enabled: false}
      cached_flag = %Flag{name: name, gates: [gate2]}

      {:ok, ^stored_flag} = PersiRedis.put(name, gate)
      :timer.sleep(10)
      {:ok, ^cached_flag} = Cache.put(cached_flag)

      assert {:ok, ^stored_flag} = PersiRedis.get(name)
      assert {:ok, ^cached_flag} = Cache.get(name)

      {:ok, name: name, stored_flag: stored_flag, cached_flag: cached_flag}
    end

    # This should be in `setup` but in there it produces a compiler warning because
    # the two variables will never match (duh).
    test "verify test setup", %{cached_flag: cached_flag, stored_flag: stored_flag} do
      refute match? ^stored_flag, cached_flag
    end


    test "when the message is not valid, the Cached value is not changed", %{name: name, cached_flag: cached_flag} do
      channel = "fun_with_flags_changes"

      Redix.command(PersiRedis, ["PUBLISH", channel, to_string(name)])
      :timer.sleep(30)
      assert {:ok, ^cached_flag} = Cache.get(name)
    end


    test "when the message comes from this same process, the Cached value is not changed", %{name: name, cached_flag: cached_flag} do
      u_id = NotifiRedis.unique_id()
      channel = "fun_with_flags_changes"
      message = "#{u_id}:#{to_string(name)}"

      Redix.command(PersiRedis, ["PUBLISH", channel, message])
      :timer.sleep(30)
      assert {:ok, ^cached_flag} = Cache.get(name)
    end


    test "when the message comes from another process, the Cached value is reloaded", %{name: name, cached_flag: cached_flag, stored_flag: stored_flag} do
      another_u_id = Config.build_unique_id()
      refute another_u_id == NotifiRedis.unique_id()

      channel = "fun_with_flags_changes"
      message = "#{another_u_id}:#{to_string(name)}"

      assert {:ok, ^cached_flag} = Cache.get(name)
      Redix.command(PersiRedis, ["PUBLISH", channel, message])
      :timer.sleep(30)
      assert {:ok, ^stored_flag} = Cache.get(name)
    end
  end
end
