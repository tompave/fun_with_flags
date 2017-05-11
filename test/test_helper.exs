IO.puts "Running tests with $TEST_OPTS='#{System.get_env("TEST_OPTS")}'"
FunWithFlags.TestUtils.use_redis_test_db()
ExUnit.start()
