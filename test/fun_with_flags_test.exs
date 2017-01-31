defmodule FunWithFlagsTest do
  use ExUnit.Case, async: true
  doctest FunWithFlags

  describe "enabled?" do
    test "it returns false for non existing feature flags" do
      assert false == FunWithFlags.enabled?(:i_do_not_exits)
    end

    test "it returns false for a disabled feature flag" do
      FunWithFlags.disable(:foobar)
      assert false == FunWithFlags.enabled?(:foobar)
    end

    test "it returns true for an enabled feature flag" do
      FunWithFlags.enable(:barbaz)
      assert true == FunWithFlags.enabled?(:barbaz)
    end
  end


  test "flags can be enabled and disabled" do
    assert false == FunWithFlags.enabled?(:domodossola)
    FunWithFlags.enable(:domodossola)
    assert true == FunWithFlags.enabled?(:domodossola)
    FunWithFlags.disable(:domodossola)
    assert false == FunWithFlags.enabled?(:domodossola)
  end


  test "enabling always returns the tuple {:ok, true} on success" do
    assert {:ok, true} = FunWithFlags.enable(:perugia)
    assert {:ok, true} = FunWithFlags.enable(:perugia)
  end

  test "disabling always returns the tuple {:ok, false} on success" do
    assert {:ok, false} = FunWithFlags.disable(:norcia)
    assert {:ok, false} = FunWithFlags.disable(:norcia)
  end
end
