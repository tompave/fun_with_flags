defmodule FunWithFlags.FlagTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.{Flag,Gate}

  describe "new(name)" do
    test "it returns a new flag struct" do
      assert %Flag{name: :pear, gates: []} = Flag.new("pear")
      assert %Flag{name: :pear, gates: []} = Flag.new(:pear)
    end
  end


  describe "enabled?(flag)" do
    test "it returns true if the flag has a boolean value = true" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, true)]}
      assert Flag.enabled?(flag)
    end

    test "it returns false if the flag has a boolean value = false" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, false)]}
      refute Flag.enabled?(flag)
    end

    test "it returns false if the flag doesn't have any gate" do
      flag = %Flag{name: :banana, gates: []}
      refute Flag.enabled?(flag)
    end
  end
end
