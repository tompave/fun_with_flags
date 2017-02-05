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
    defaults = [host: 'localhost', port: 6379]
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
  end



  defp configure_redis_with(conf) do
    Mix.Config.persist(fun_with_flags: [redis: conf])
    assert ^conf = Application.get_env(:fun_with_flags, :redis)
  end

  defp ensure_no_redis_config do
    assert match?(nil, Application.get_env(:fun_with_flags, :redis))
    refute Keyword.has_key?(Application.get_all_env(:fun_with_flags), :redis)
  end
end
