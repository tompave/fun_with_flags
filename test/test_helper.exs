IO.puts "Running the tests with Mix.env: #{Mix.env}"
FunWithFlags.TestUtils.use_redis_test_db()
ExUnit.start()
