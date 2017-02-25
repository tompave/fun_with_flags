defmodule FunWithFlags.GateTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Gate

  describe "new()" do
    test "new(:boolean, true|false) returns a new Boolean Gate" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Gate.new(:boolean, true)
      assert %Gate{type: :boolean, for: nil, enabled: false} = Gate.new(:boolean, false)
    end
  end


  describe "from_redis() returns a Gate struct" do
    test "with boolean data" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Gate.from_redis(["boolean", "true"])
      assert %Gate{type: :boolean, for: nil, enabled: false} = Gate.from_redis(["boolean", "false"])
    end
  end


  describe "enabled?(gate), for boolean gates" do
    test "it simply check the value of the gate" do
      gate = %Gate{type: :boolean, for: nil, enabled: true}
      assert Gate.enabled?(gate)

      gate = %Gate{type: :boolean, for: nil, enabled: false}
      refute Gate.enabled?(gate)
    end
  end


  describe "boolean?(gate)" do
    test "a boolean gate" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      assert Gate.boolean?(gate)
    end
  end
end
