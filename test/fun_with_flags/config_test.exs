defmodule FunWithFlags.ConfigTest do
  use FunWithFlags.TestCase, async: true
  alias FunWithFlags.Config

  import FunWithFlags.TestUtils, only: [
    configure_redis_with: 1,
    ensure_default_redis_config_in_app_env: 0,
    reset_app_env_to_default_redis_config: 0,
  ]

  # Test all of these in the same test case because Mix provides
  # no API to clear or reset the App configuration. Since the test
  # order is randomized, testing these cases separately makes them
  # non-deterministic and causes random failures.
  #
  # The good thing is that the OTP app is started _before_ the
  # tests, thus changing this configuration should not affect the
  # Redis connection.
  #
  test "the redis configuration" do
    # without configuration, it returns the defaults
    ensure_default_redis_config_in_app_env()
    defaults = [host: "localhost", port: 6379, database: 5]
    assert ^defaults = Config.redis_config

    # when configured to use a URL string, it returns the string and ignores the defaults
    url = "redis:://localhost:1234/1"
    configure_redis_with(url)
    assert ^url = Config.redis_config

    # when configured to use a URL + Redis config tuple, it returns the tuple and ignores the defaults
    url = "redis:://localhost:1234/1"
    configure_redis_with({url, socket_opts: [:inet6]})
    {^url, opts} = Config.redis_config
    assert [socket_opts: [:inet6]] == opts

    # when configured to use sentinel, it returns sentinel without default host and port
    sentinel = [sentinel: [sentinels: ["redis:://locahost:1234/1"], group: "primary"], database: 5]
    configure_redis_with(sentinel)
    assert ^sentinel = Config.redis_config

    # when configured with keywords, it merges them with the default
    configure_redis_with(database: 42, port: 2000)
    assert defaults[:host] == Config.redis_config[:host]
    assert            2000 == Config.redis_config[:port]
    assert              42 == Config.redis_config[:database]

    # When configured with a {:system, env} tuple it looks up the value in the env
    System.put_env("123_TEST_REDIS_URL", url)
    configure_redis_with({:system, "123_TEST_REDIS_URL"})
    assert url == Config.redis_config
    System.delete_env("123_TEST_REDIS_URL")

    # cleanup
    reset_app_env_to_default_redis_config()
  end


  test "cache?" do
    # defaults to true
    assert true == Config.cache?

    # can be configured
    Application.put_all_env(fun_with_flags: [cache: [enabled: false]])
    assert false == Config.cache?

    # cleanup
    reset_cache_defaults()
    assert true == Config.cache?
  end


  test "cache_ttl" do
    # defaults to 60 seconds in test
    assert 60 = Config.cache_ttl

    # can be configured
    Application.put_all_env(fun_with_flags: [cache: [ttl: 3600]])
    assert 3600 = Config.cache_ttl

    # cleanup
    reset_cache_defaults()
    assert 60 = Config.cache_ttl
  end


  @tag :integration
  test "store_module_determined_at_compile_time()" do
    # This is not great, but testing compile time stuff is tricky.
    if Config.cache?() do
      assert FunWithFlags.Store = Config.store_module_determined_at_compile_time()
    else
      assert FunWithFlags.SimpleStore = Config.store_module_determined_at_compile_time()
    end
  end


  test "build_unique_id() returns a unique string" do
    assert is_binary(Config.build_unique_id)

    list = Enum.map(1..20, fn(_) -> Config.build_unique_id() end)
    assert length(list) == length(Enum.uniq(list))
  end


  describe "When we are persisting data in Redis" do
    @describetag :redis_persistence
    test "persistence_adapter() returns the Redis module" do
      assert FunWithFlags.Store.Persistent.Redis = Config.persistence_adapter
    end

    test "persist_in_ecto? returns false" do
      refute Config.persist_in_ecto?
    end

    test "ecto_repo() returns the null repo" do
      assert FunWithFlags.NullEctoRepo = Config.ecto_repo
    end
  end

  describe "When we are persisting data in Ecto" do
    @describetag :ecto_persistence
    test "persistence_adapter() returns the Ecto module" do
      assert FunWithFlags.Store.Persistent.Ecto = Config.persistence_adapter
    end

    test "persist_in_ecto? returns true" do
      assert Config.persist_in_ecto?
    end

    test "ecto_repo() returns a repo" do
      assert FunWithFlags.Dev.EctoRepo = Config.ecto_repo
    end
  end

  describe "ecto_table_name_determined_at_compile_time()" do
    test "it defaults to \"fun_with_flags_toggles\"" do
      assert Config.ecto_table_name_determined_at_compile_time() == "fun_with_flags_toggles"
    end
  end

  describe "ecto_primary_key_type_determined_at_compile_time()" do
    test "it defaults to :id" do
      assert Config.ecto_primary_key_type_determined_at_compile_time() == :id
    end
  end

  describe "When we are sending notifications with Redis PubSub" do
    @describetag :redis_pubsub

    test "notifications_adapter() returns the Redis module" do
      assert FunWithFlags.Notifications.Redis = Config.notifications_adapter
    end

    test "phoenix_pubsub? returns false" do
      refute Config.phoenix_pubsub?
    end

    test "pubsub_client() returns nil" do
      assert is_nil(Config.pubsub_client)
    end
  end

  describe "When we are sending notifications with Phoenix.PubSub" do
    @describetag :phoenix_pubsub

    test "notifications_adapter() returns the Redis module" do
      assert FunWithFlags.Notifications.PhoenixPubSub = Config.notifications_adapter
    end

    test "phoenix_pubsub? returns true" do
      assert Config.phoenix_pubsub?
    end

    test "pubsub_client() returns an atom" do
      assert :fwf_test = Config.pubsub_client
    end
  end


  describe "change_notifications_enabled?()" do
    test "returns true by default" do
      assert Config.change_notifications_enabled?
    end

    test "returns false if the cache is disabled" do
      Application.put_all_env(fun_with_flags: [cache: [enabled: false]])
      refute Config.change_notifications_enabled?

      # cleanup
      reset_cache_defaults()
      assert Config.change_notifications_enabled?
    end

    test "returns false if no notification adapter is configured" do
      original_adapter = Config.notifications_adapter()
      original_client = Config.pubsub_client
      Application.put_all_env(fun_with_flags: [cache_bust_notifications: [adapter: nil]])
      refute Config.change_notifications_enabled?

      # cleanup
      reset_notifications_defaults(original_adapter, original_client)
      assert Config.change_notifications_enabled?
    end

    test "returns false if it's explicitly disabled" do
      original_adapter = Config.notifications_adapter()
      original_client = Config.pubsub_client
      Application.put_all_env(fun_with_flags: [cache_bust_notifications: [enabled: false]])
      refute Config.change_notifications_enabled?

      # cleanup
      reset_notifications_defaults(original_adapter, original_client)
      assert Config.change_notifications_enabled?
    end
  end

  defp reset_cache_defaults do
    Application.put_all_env(fun_with_flags: [cache: [enabled: true, ttl: 60]])
  end

  defp reset_notifications_defaults(adapter, client) do
    Application.put_all_env(fun_with_flags: [
      cache_bust_notifications: [
        enabled: true, adapter: adapter, client: client
      ]
    ])
  end
end
