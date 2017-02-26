defmodule FunWithFlags.FlagTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.{Flag,Gate}

  describe "new(name)" do
    test "it returns a new flag struct" do
      assert %Flag{name: :pear, gates: []} = Flag.new(:pear)
    end
  end


  describe "from_redis(name, [gate, data])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Flag.from_redis(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag" do
      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: true}]} =
          Flag.from_redis(:kiwi, ["boolean", "true"])
      )

      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: false}]} =
          Flag.from_redis(:kiwi, ["boolean", "false"])
      )
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
