defmodule FunWithFlags.Store.SerializerTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Gate
  alias FunWithFlags.Store.Serializer

  describe "to_redis(gate) returns a List ready to be saved in Redis" do
    test "with a boolean gate" do
      gate = Gate.new(:boolean, true)
      assert ["boolean", "true"] = Serializer.to_redis(gate)

      gate = Gate.new(:boolean, false)
      assert ["boolean", "false"] = Serializer.to_redis(gate)
    end


    test "with an actor gate" do
      gate = %Gate{type: :actor, for: "user:42", enabled: true}
      assert ["actor/user:42", "true"] = Serializer.to_redis(gate)

      gate = %Gate{type: :actor, for: "user:123", enabled: false}
      assert ["actor/user:123", "false"] = Serializer.to_redis(gate)
    end


    test "with a group gate" do
      gate = %Gate{type: :group, for: :runners, enabled: true}
      assert ["group/runners", "true"] = Serializer.to_redis(gate)

      gate = %Gate{type: :group, for: :swimmers, enabled: false}
      assert ["group/swimmers", "false"] = Serializer.to_redis(gate)
    end
  end
end
