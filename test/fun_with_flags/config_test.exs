defmodule FunWithFlags.ConfigTest do
  use ExUnit.Case, async: true
  alias FunWithFlags.Config

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
    ensure_no_redis_config()
    defaults = [host: 'localhost', port: 6379, database: 5]
    assert ^defaults = Config.redis_config

    # when configured to use a URL string, it returns the string and ignores the defaults
    url = "redis:://locahost:1234/1"
    configure_redis_with(url)
    assert ^url = Config.redis_config

    # when confgured with keywords, it merges them with the default
    configure_redis_with(database: 42, port: 2000)
    assert defaults[:host] == Config.redis_config[:host]
    assert            2000 == Config.redis_config[:port]
    assert              42 == Config.redis_config[:database]

    # cleanup
    configure_redis_with(defaults)
  end


  test "cache?" do
    # defaults to true
    assert true == Config.cache?

    # can be configured
    Mix.Config.persist(fun_with_flags: [cache: [enabled: false]])
    assert false == Config.cache?

    # cleanup
    reset_cache_defaults()
    assert true == Config.cache?
  end


  test "cache_ttl" do
    # defaults to 60 seconds in test
    assert 60 = Config.cache_ttl

    # can be configured
    Mix.Config.persist(fun_with_flags: [cache: [ttl: 3600]])
    assert 3600 = Config.cache_ttl

    # cleanup
    reset_cache_defaults()
    assert 60 = Config.cache_ttl
  end


  test "store_module" do
    # defaults to FunWithFlags.Store
    assert FunWithFlags.Store = Config.store_module

    # can be configured
    Mix.Config.persist(fun_with_flags: [cache: [enabled: false]])
    assert FunWithFlags.SimpleStore = Config.store_module

    # cleanup
    reset_cache_defaults()
    assert FunWithFlags.Store = Config.store_module
  end


  test "build_unique_id() returns a unique string" do
    assert is_binary(Config.build_unique_id)

    list = Enum.map(1..20, fn(_) -> Config.build_unique_id() end)
    assert length(list) == length(Enum.uniq(list))
  end


  test "persistence_adapter() returns a module" do
    assert FunWithFlags.Store.Persistent.Redis = Config.persistence_adapter
  end

  defp configure_redis_with(conf) do
    Mix.Config.persist(fun_with_flags: [redis: conf])
    assert ^conf = Application.get_env(:fun_with_flags, :redis)
  end

  defp ensure_no_redis_config do
    assert match?([database: 5], Application.get_env(:fun_with_flags, :redis))
  end

  defp reset_cache_defaults do
    Mix.Config.persist(fun_with_flags: [cache: [enabled: true, ttl: 60]])
  end
end
