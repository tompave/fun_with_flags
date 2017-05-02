defmodule FunWithFlags.Store.SerializerTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Flag
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

  describe "flag_from_redis(name, [gate, data])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Serializer.flag_from_redis(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag" do
      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: true}]} =
          Serializer.flag_from_redis(:kiwi, ["boolean", "true"])
      )

      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: false}]} =
          Serializer.flag_from_redis(:kiwi, ["boolean", "false"])
      )
    end

    test "with more than one gate it returns a composite flag" do
      flag = %Flag{name: :peach, gates: [
        %Gate{type: :boolean, enabled: true},
        %Gate{type: :actor, for: "user:123", enabled: false},
      ]}
      assert ^flag = Serializer.flag_from_redis(:peach, ["boolean", "true", "actor/user:123", "false"])

      flag = %Flag{name: :apricot, gates: [
        %Gate{type: :actor, for: "string:albicocca", enabled: true},
        %Gate{type: :boolean, enabled: false},
        %Gate{type: :actor, for: "user:123", enabled: false},
        %Gate{type: :group, for: :penguins, enabled: true},
      ]}

      raw_redis_data = [
        "actor/string:albicocca", "true",
        "boolean", "false",
        "actor/user:123", "false",
        "group/penguins", "true"
      ]
      assert ^flag = Serializer.flag_from_redis(:apricot, raw_redis_data)
    end
  end

  describe "gate_from_redis() returns a Gate struct" do
    test "with boolean data" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Serializer.gate_from_redis(["boolean", "true"])
      assert %Gate{type: :boolean, for: nil, enabled: false} = Serializer.gate_from_redis(["boolean", "false"])
    end

    test "with actor data" do
      assert %Gate{type: :actor, for: "anything", enabled: true} = Serializer.gate_from_redis(["actor/anything", "true"])
      assert %Gate{type: :actor, for: "really:123", enabled: false} = Serializer.gate_from_redis(["actor/really:123", "false"])
    end

    test "with group data" do
      assert %Gate{type: :group, for: :fishes, enabled: true} = Serializer.gate_from_redis(["group/fishes", "true"])
      assert %Gate{type: :group, for: :cetacea, enabled: false} = Serializer.gate_from_redis(["group/cetacea", "false"])
    end
  end

end
