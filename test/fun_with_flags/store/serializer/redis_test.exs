defmodule FunWithFlags.Store.Serializer.RedisTest do
  use FunWithFlags.TestCase, async: true

  alias FunWithFlags.Flag
  alias FunWithFlags.Gate
  alias FunWithFlags.Store.Serializer.Redis, as: Serializer

  describe "serialize(gate) returns a List ready to be saved in Redis" do
    test "with a boolean gate" do
      gate = Gate.new(:boolean, true)
      assert ["boolean", "true"] = Serializer.serialize(gate)

      gate = Gate.new(:boolean, false)
      assert ["boolean", "false"] = Serializer.serialize(gate)
    end

    test "with an actor gate" do
      gate = %Gate{type: :actor, for: "user:42", enabled: true}
      assert ["actor/user:42", "true"] = Serializer.serialize(gate)

      gate = %Gate{type: :actor, for: "user:123", enabled: false}
      assert ["actor/user:123", "false"] = Serializer.serialize(gate)
    end

    test "with a group gate" do
      gate = %Gate{type: :group, for: :runners, enabled: true}
      assert ["group/runners", "true"] = Serializer.serialize(gate)

      gate = %Gate{type: :group, for: :swimmers, enabled: false}
      assert ["group/swimmers", "false"] = Serializer.serialize(gate)

      gate = %Gate{type: :group, for: "runners", enabled: true}
      assert ["group/runners", "true"] = Serializer.serialize(gate)

      gate = %Gate{type: :group, for: "swimmers", enabled: false}
      assert ["group/swimmers", "false"] = Serializer.serialize(gate)
    end

    test "with a percentage_of_time gate" do
      gate = %Gate{type: :percentage_of_time, for: 0.123, enabled: true}
      assert ["percentage", "time/0.123"] = Serializer.serialize(gate)

      gate = %Gate{type: :percentage_of_time, for: 0.42, enabled: true}
      assert ["percentage", "time/0.42"] = Serializer.serialize(gate)
    end

    test "with a percentage_of_actors gate" do
      gate = %Gate{type: :percentage_of_actors, for: 0.123, enabled: true}
      assert ["percentage", "actors/0.123"] = Serializer.serialize(gate)

      gate = %Gate{type: :percentage_of_actors, for: 0.42, enabled: true}
      assert ["percentage", "actors/0.42"] = Serializer.serialize(gate)
    end
  end

  describe "deserialize_flag(name, [gate, data])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Serializer.deserialize_flag(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag" do
      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: true}]} =
          Serializer.deserialize_flag(:kiwi, ["boolean", "true"])
      )

      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: false}]} =
          Serializer.deserialize_flag(:kiwi, ["boolean", "false"])
      )
    end

    test "with more than one gate it returns a composite flag" do
      flag = %Flag{
        name: :peach,
        gates: [
          %Gate{type: :boolean, enabled: true},
          %Gate{type: :actor, for: "user:123", enabled: false}
        ]
      }

      assert ^flag =
               Serializer.deserialize_flag(:peach, ["boolean", "true", "actor/user:123", "false"])

      flag = %Flag{
        name: :apricot,
        gates: [
          %Gate{type: :actor, for: "string:albicocca", enabled: true},
          %Gate{type: :boolean, enabled: false},
          %Gate{type: :percentage_of_time, for: 0.5, enabled: true},
          %Gate{type: :actor, for: "user:123", enabled: false},
          %Gate{type: :group, for: "penguins", enabled: true}
        ]
      }

      raw_redis_data = [
        "actor/string:albicocca",
        "true",
        "boolean",
        "false",
        "percentage",
        "time/0.5",
        "actor/user:123",
        "false",
        "group/penguins",
        "true"
      ]

      assert ^flag = Serializer.deserialize_flag(:apricot, raw_redis_data)

      flag = %Flag{
        name: :apricot,
        gates: [
          %Gate{type: :actor, for: "string:albicocca", enabled: true},
          %Gate{type: :boolean, enabled: false},
          %Gate{type: :percentage_of_actors, for: 0.5, enabled: true},
          %Gate{type: :group, for: "penguins", enabled: true}
        ]
      }

      raw_redis_data = [
        "actor/string:albicocca",
        "true",
        "boolean",
        "false",
        "percentage",
        "actors/0.5",
        "group/penguins",
        "true"
      ]

      assert ^flag = Serializer.deserialize_flag(:apricot, raw_redis_data)
    end
  end

  describe "deserialize_gate() returns a Gate struct" do
    test "with boolean data" do
      assert %Gate{type: :boolean, for: nil, enabled: true} =
               Serializer.deserialize_gate(["boolean", "true"])

      assert %Gate{type: :boolean, for: nil, enabled: false} =
               Serializer.deserialize_gate(["boolean", "false"])
    end

    test "with actor data" do
      assert %Gate{type: :actor, for: "anything", enabled: true} =
               Serializer.deserialize_gate(["actor/anything", "true"])

      assert %Gate{type: :actor, for: "really:123", enabled: false} =
               Serializer.deserialize_gate(["actor/really:123", "false"])
    end

    test "with group data" do
      assert %Gate{type: :group, for: "fishes", enabled: true} =
               Serializer.deserialize_gate(["group/fishes", "true"])

      assert %Gate{type: :group, for: "cetacea", enabled: false} =
               Serializer.deserialize_gate(["group/cetacea", "false"])
    end

    test "with percentage_of_time data" do
      assert %Gate{type: :percentage_of_time, for: 0.001, enabled: true} =
               Serializer.deserialize_gate(["percentage", "time/0.001"])

      assert %Gate{type: :percentage_of_time, for: 0.95, enabled: true} =
               Serializer.deserialize_gate(["percentage", "time/0.95"])
    end

    test "with percentage_of_actors data" do
      assert %Gate{type: :percentage_of_actors, for: 0.001, enabled: true} =
               Serializer.deserialize_gate(["percentage", "actors/0.001"])

      assert %Gate{type: :percentage_of_actors, for: 0.95, enabled: true} =
               Serializer.deserialize_gate(["percentage", "actors/0.95"])
    end
  end
end
