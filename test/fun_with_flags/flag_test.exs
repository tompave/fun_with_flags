defmodule FunWithFlags.FlagTest do
  use ExUnit.Case, async: true
  import FunWithFlags.TestUtils

  alias FunWithFlags.Flag

  describe "enabled?(flag)" do
    setup do
      flag = %Flag{boolean: true} = make_flag("foobar", true)
      {:ok, flag: flag}
    end

    test "it returns true if the flag has a boolean value = true", %{flag: flag} do
      assert Flag.enabled?(flag)
    end

    test "it returns false if the flag has a boolean value = false", %{flag: flag} do
      flag = %Flag{flag | boolean: false}
      refute Flag.enabled?(flag)
    end
  end
end
