defmodule FunWithFlags.Store.Serializer.EctoTest do
  use FunWithFlags.TestCase, async: true

  alias FunWithFlags.Flag
  alias FunWithFlags.Gate
  alias FunWithFlags.Store.Persistent.Ecto.Record
  alias FunWithFlags.Store.Serializer.Ecto, as: Serializer

  setup do
    flag_name = "chicken"

    bool_record = %Record{
      enabled: true,
      flag_name: flag_name,
      gate_type: "boolean",
      id: 2,
      target: nil
    }

    actor_record = %Record{
      enabled: true,
      flag_name: flag_name,
      gate_type: "actor",
      id: 4,
      target: "user:123"
    }

    group_record = %Record{
      enabled: false,
      flag_name: flag_name,
      gate_type: "group",
      id: 3,
      target: "admins"
    }

    po_time_record = %Record{
      enabled: true,
      flag_name: flag_name,
      gate_type: "percentage",
      id: 5,
      target: "time/0.42"
    }

    po_actors_record = %Record{
      enabled: true,
      flag_name: flag_name,
      gate_type: "percentage",
      id: 5,
      target: "actors/0.42"
    }

    {:ok,
     flag_name: String.to_atom(flag_name),
     bool_record: bool_record,
     actor_record: actor_record,
     group_record: group_record,
     percentage_of_time_record: po_time_record,
     percentage_of_actors_record: po_actors_record}
  end

  describe "deserialize_flag(name, [%Record{}])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Serializer.deserialize_flag(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag", %{
      flag_name: flag_name,
      bool_record: bool_record
    } do
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
         %{
           flag_name: flag_name,
           bool_record: bool_record,
           actor_record: actor_record,
           group_record: group_record,
           percentage_of_time_record: percentage_of_time_record,
           percentage_of_actors_record: percentage_of_actors_record
         } do
      flag = %Flag{
        name: flag_name,
        gates: [
          %Gate{type: :actor, for: "user:123", enabled: true},
          %Gate{type: :boolean, enabled: true},
          %Gate{type: :group, for: "admins", enabled: false}
        ]
      }

      assert ^flag =
               Serializer.deserialize_flag(flag_name, [bool_record, actor_record, group_record])

      flag = %Flag{
        name: flag_name,
        gates: [
          %Gate{type: :actor, for: "user:123", enabled: true},
          %Gate{type: :actor, for: "string:albicocca", enabled: false},
          %Gate{type: :boolean, enabled: true},
          %Gate{type: :group, for: "admins", enabled: false},
          %Gate{type: :group, for: "penguins", enabled: true},
          %Gate{type: :percentage_of_time, for: 0.42, enabled: true}
        ]
      }

      actor_record_2 = %{actor_record | id: 5, target: "string:albicocca", enabled: false}
      group_record_2 = %{group_record | id: 6, target: "penguins", enabled: true}

      assert ^flag =
               Serializer.deserialize_flag(
                 flag_name,
                 [
                   bool_record,
                   actor_record,
                   group_record,
                   actor_record_2,
                   group_record_2,
                   percentage_of_time_record
                 ]
               )

      flag = %Flag{
        name: flag_name,
        gates: [
          %Gate{type: :actor, for: "string:albicocca", enabled: false},
          %Gate{type: :boolean, enabled: true},
          %Gate{type: :group, for: "penguins", enabled: true},
          %Gate{type: :percentage_of_actors, for: 0.42, enabled: true}
        ]
      }

      actor_record_2 = %{actor_record | id: 5, target: "string:albicocca", enabled: false}
      group_record_2 = %{group_record | id: 6, target: "penguins", enabled: true}

      assert ^flag =
               Serializer.deserialize_flag(
                 flag_name,
                 [
                   bool_record,
                   actor_record_2,
                   group_record_2,
                   percentage_of_actors_record
                 ]
               )
    end
  end

  describe "deserialize_gate(flag_name, %Record{}) returns a Gate struct" do
    setup(shared) do
      {:ok, flag_name: to_string(shared.flag_name)}
    end

    test "with boolean data", %{flag_name: flag_name, bool_record: bool_record} do
      bool_record = %{bool_record | enabled: true}

      assert %Gate{type: :boolean, for: nil, enabled: true} =
               Serializer.deserialize_gate(flag_name, bool_record)

      bool_record = %{bool_record | enabled: false}

      assert %Gate{type: :boolean, for: nil, enabled: false} =
               Serializer.deserialize_gate(flag_name, bool_record)
    end

    test "with actor data", %{flag_name: flag_name, actor_record: actor_record} do
      actor_record = %{actor_record | enabled: true}

      assert %Gate{type: :actor, for: "user:123", enabled: true} =
               Serializer.deserialize_gate(flag_name, actor_record)

      actor_record = %{actor_record | enabled: false}

      assert %Gate{type: :actor, for: "user:123", enabled: false} =
               Serializer.deserialize_gate(flag_name, actor_record)
    end

    test "with group data", %{flag_name: flag_name, group_record: group_record} do
      group_record = %{group_record | enabled: true}

      assert %Gate{type: :group, for: "admins", enabled: true} =
               Serializer.deserialize_gate(flag_name, group_record)

      group_record = %{group_record | enabled: false}

      assert %Gate{type: :group, for: "admins", enabled: false} =
               Serializer.deserialize_gate(flag_name, group_record)
    end

    test "with percentage_of_time data", %{
      flag_name: flag_name,
      percentage_of_time_record: percentage_of_time_record
    } do
      assert %Gate{type: :percentage_of_time, for: 0.42, enabled: true} =
               Serializer.deserialize_gate(flag_name, percentage_of_time_record)
    end

    test "with percentage_of_actors data", %{
      flag_name: flag_name,
      percentage_of_actors_record: percentage_of_actors_record
    } do
      assert %Gate{type: :percentage_of_actors, for: 0.42, enabled: true} =
               Serializer.deserialize_gate(flag_name, percentage_of_actors_record)
    end
  end
end
