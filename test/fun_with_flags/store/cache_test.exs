defmodule FunWithFlags.Store.CacheTest do
  use ExUnit.Case, async: true
  import FunWithFlags.TestUtils

  alias FunWithFlags.Store.Cache

  # No need to start it as it's in the supervision tree, but:
  #
  # setup_all do
  #   {:ok, _cache} = Cache.start_link
  #   :ok
  # end

  test "looking up an undefined flag returns false" do
    flag_name = unique_atom()
    assert false == Cache.get(flag_name)
  end

  test "put() can change the value of a flag" do
    flag_name = unique_atom()

    assert false == Cache.get(flag_name)
    Cache.put(flag_name, true)
    assert true == Cache.get(flag_name)
    Cache.put(flag_name, false)
    assert false == Cache.get(flag_name)
  end

  test "put() returns the tuple {:ok, a_boolean_value}" do
    flag_name = unique_atom()
    assert {:ok, true} == Cache.put(flag_name, true)
    assert {:ok, false} == Cache.put(flag_name, false)
  end

  test "get() returns a boolean" do
    flag_name = unique_atom()
    assert false == Cache.get(flag_name)
    Cache.put(flag_name, true)
    assert true == Cache.get(flag_name)
  end


  test "present?() checks if a flag is already stored, it returns {:found, flag_value}" do
    flag_name = unique_atom()
    assert :not_found = Cache.present?(flag_name)
    Cache.put(flag_name, false)
    assert {:found, false} = Cache.present?(flag_name)
    Cache.put(flag_name, true)
    assert {:found, true} = Cache.present?(flag_name)
  end

  describe "unit: enable and disable with this module's API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      Cache.put(flag_name, false)
      assert false == Cache.get(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      Cache.put(flag_name, true)
      assert true == Cache.get(flag_name)
    end
  end

  describe "integration: enable and disable with the top-level API" do
    setup do
      # can't use setup_all in here, but the on_exit should
      # be run only once because it's identifed by a common ref
      on_exit(:cache_integration_group, fn() -> clear_redis_test_db() end)
      :ok
    end

    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == Cache.get(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == Cache.get(flag_name)
    end
  end    
end
