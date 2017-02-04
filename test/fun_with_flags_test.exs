defmodule FunWithFlagsTest do
  use ExUnit.Case, async: true
  import FunWithFlags.TestUtils
  doctest FunWithFlags

  describe "enabled?" do
    test "it returns false for non existing feature flags" do
      flag_name = unique_atom()
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns false for a disabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns true for an enabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)
    end
  end


  test "flags can be enabled and disabled" do
    flag_name = unique_atom()
    assert false == FunWithFlags.enabled?(flag_name)
    FunWithFlags.enable(flag_name)
    assert true == FunWithFlags.enabled?(flag_name)
    FunWithFlags.disable(flag_name)
    assert false == FunWithFlags.enabled?(flag_name)
  end


  test "enabling always returns the tuple {:ok, true} on success" do
    flag_name = unique_atom()
    assert {:ok, true} = FunWithFlags.enable(flag_name)
    assert {:ok, true} = FunWithFlags.enable(flag_name)
  end

  test "disabling always returns the tuple {:ok, false} on success" do
    flag_name = unique_atom()
    assert {:ok, false} = FunWithFlags.disable(flag_name)
    assert {:ok, false} = FunWithFlags.disable(flag_name)
  end
end
