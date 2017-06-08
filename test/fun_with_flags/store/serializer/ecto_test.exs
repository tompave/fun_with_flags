defmodule FunWithFlags.Store.Serializer.EctoTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Flag
  alias FunWithFlags.Gate
  alias FunWithFlags.Store.Persistent.Ecto.Record
  alias FunWithFlags.Store.Serializer.Ecto, as: Serializer

  setup do
    flag_name = "chicken"
    bool_record  = %Record{enabled: true, flag_name: flag_name, gate_type: "boolean", id: 2, target: nil}
    actor_record = %Record{enabled: true, flag_name: flag_name, gate_type: "actor", id: 4,target: "user:123"}
    group_record = %Record{enabled: false, flag_name: flag_name, gate_type: "group", id: 3, target: "admins"}
    {:ok, flag_name: String.to_atom(flag_name), bool_record: bool_record, actor_record: actor_record, group_record: group_record}
  end

  describe "deserialize_flag(name, [%Record{}])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Serializer.deserialize_flag(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag", %{flag_name: flag_name, bool_record: bool_record} do
      assert(
        %Flag{name: ^flag_name, gates: [%Gate{type: :boolean, enabled: true}]} =
          Serializer.deserialize_flag(flag_name, [bool_record])
      )

      disabled_bool_record = %{bool_record | enabled: false}
      assert(
        %Flag{name: ^flag_name, gates: [%Gate{type: :boolean, enabled: false}]} =
          Serializer.deserialize_flag(flag_name, [disabled_bool_record])
      )
    end


    test "with more than one gate it returns a composite flag",
         %{flag_name: flag_name, bool_record: bool_record, actor_record: actor_record, group_record: group_record} do

      flag = %Flag{name: flag_name, gates: [
        %Gate{type: :boolean, enabled: true},
        %Gate{type: :actor, for: "user:123", enabled: true},
        %Gate{type: :group, for: :admins, enabled: false},
      ]}
      assert ^flag = Serializer.deserialize_flag(flag_name, [bool_record, actor_record, group_record])

      # flag = %Flag{name: :apricot, gates: [
      #   %Gate{type: :actor, for: "string:albicocca", enabled: true},
      #   %Gate{type: :boolean, enabled: false},
      #   %Gate{type: :actor, for: "user:123", enabled: false},
      #   %Gate{type: :group, for: :penguins, enabled: true},
      # ]}

      # raw_redis_data = [
      #   "actor/string:albicocca", "true",
      #   "boolean", "false",
      #   "actor/user:123", "false",
      #   "group/penguins", "true"
      # ]
      # assert ^flag = Serializer.deserialize_flag(:apricot, raw_redis_data)
    end
  end

  # describe "deserialize_gate() returns a Gate struct" do
  #   test "with boolean data" do
  #     assert %Gate{type: :boolean, for: nil, enabled: true} = Serializer.deserialize_gate(["boolean", "true"])
  #     assert %Gate{type: :boolean, for: nil, enabled: false} = Serializer.deserialize_gate(["boolean", "false"])
  #   end

  #   test "with actor data" do
  #     assert %Gate{type: :actor, for: "anything", enabled: true} = Serializer.deserialize_gate(["actor/anything", "true"])
  #     assert %Gate{type: :actor, for: "really:123", enabled: false} = Serializer.deserialize_gate(["actor/really:123", "false"])
  #   end

  #   test "with group data" do
  #     assert %Gate{type: :group, for: :fishes, enabled: true} = Serializer.deserialize_gate(["group/fishes", "true"])
  #     assert %Gate{type: :group, for: :cetacea, enabled: false} = Serializer.deserialize_gate(["group/cetacea", "false"])
  #   end
  # end

end
