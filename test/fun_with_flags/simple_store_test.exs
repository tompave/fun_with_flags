defmodule FunWithFlags.SimpleStoreTest do
  use ExUnit.Case
  import FunWithFlags.TestUtils

  alias FunWithFlags.SimpleStore

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    # disable_the_cache()
    :ok
  end

  test "looking up an undefined flag returns false" do
    flag_name = unique_atom()
    assert false == SimpleStore.lookup(flag_name)
  end

  test "put() can change the value of a flag" do
    flag_name = unique_atom()

    assert false == SimpleStore.lookup(flag_name)
    SimpleStore.put(flag_name, true)
    assert true == SimpleStore.lookup(flag_name)
    SimpleStore.put(flag_name, false)
    assert false == SimpleStore.lookup(flag_name)
  end

  test "put() returns the tuple {:ok, a_boolean_value}" do
    flag_name = unique_atom()
    assert {:ok, true} == SimpleStore.put(flag_name, true)
    assert {:ok, false} == SimpleStore.put(flag_name, false)
  end

  describe "unit: enable and disable with this module's API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      SimpleStore.put(flag_name, false)
      assert false == SimpleStore.lookup(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      SimpleStore.put(flag_name, true)
      assert true == SimpleStore.lookup(flag_name)
    end
  end

  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == SimpleStore.lookup(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == SimpleStore.lookup(flag_name)
    end
  end

end
