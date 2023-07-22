defmodule FunWithFlags.SupervisorTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils

  alias FunWithFlags.Config

  test "the auto-generated child_spec/1" do
    expected = %{
      id: FunWithFlags.Supervisor,
      start: {FunWithFlags.Supervisor, :start_link, [nil]},
      type: :supervisor
    }

    assert ^expected = FunWithFlags.Supervisor.child_spec(nil)
  end

  describe "initializing the config for the children" do
    @tag :redis_persistence
    @tag :redis_pubsub
    test "with Redis persistence and Redis PubSub" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          [
            %{
              id: FunWithFlags.Store.Cache,
              restart: :permanent,
              start: {FunWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: FunWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            },
            %{
              id: FunWithFlags.Notifications.Redis,
              restart: :permanent,
              start: {FunWithFlags.Notifications.Redis, :start_link, [
                [host: "localhost", port: 6379, database: 5, name: :fun_with_flags_notifications, sync_connect: false]
              ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end

    @tag :redis_persistence
    @tag :phoenix_pubsub
    test "with Redis persistence and Phoenix PubSub" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          [
            %{
              id: FunWithFlags.Store.Cache,
              restart: :permanent,
              start: {FunWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: FunWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            },
            %{
              id: FunWithFlags.Notifications.PhoenixPubSub,
              restart: :permanent,
              start: {FunWithFlags.Notifications.PhoenixPubSub, :start_link, []},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end

    @tag :ecto_persistence
    @tag :phoenix_pubsub
    test "with Ecto persistence and Phoenix PubSub" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          [
            %{
              id: FunWithFlags.Store.Cache,
              restart: :permanent,
              start: {FunWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: FunWithFlags.Notifications.PhoenixPubSub,
              restart: :permanent,
              start: {FunWithFlags.Notifications.PhoenixPubSub, :start_link, []},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end
  end


  describe "initializing the config for the children (no cache)" do
    setup do
      # Capture the original cache config
      original_cache_config = Config.ets_cache_config()

      # Disable the cache for these tests.
      Application.put_all_env(fun_with_flags: [cache: [
        enabled: false, ttl: original_cache_config[:ttl]
      ]])

      # Restore the original config
      on_exit fn ->
        Application.put_all_env(fun_with_flags: [cache: original_cache_config])
        assert ^original_cache_config = Config.ets_cache_config()
      end
    end

    @tag :redis_persistence
    @tag :redis_pubsub
    test "with Redis persistence and Redis PubSub, no cache" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          [
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: FunWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end

    @tag :redis_persistence
    @tag :phoenix_pubsub
    test "with Redis persistence and Phoenix PubSub, no cache" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          [
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: FunWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end

    @tag :ecto_persistence
    @tag :phoenix_pubsub
    test "with Ecto persistence and Phoenix PubSub, no cache" do
      expected = {
        :ok,
        {
          expected_supervisor_spec(),
          []
        }
      }

      assert ^expected = FunWithFlags.Supervisor.init(nil)
    end
  end

  defp expected_supervisor_spec do
    if on_elixir_15?() do
      %{intensity: 3, period: 5, strategy: :one_for_one, auto_shutdown: :never}
    else
      %{intensity: 3, period: 5, strategy: :one_for_one}
    end
  end
end
