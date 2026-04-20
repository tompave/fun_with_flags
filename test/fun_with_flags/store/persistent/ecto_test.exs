defmodule FunWithFlags.Store.Persistent.EctoTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils

  alias FunWithFlags.Store.Persistent.Ecto, as: PersiEcto
  alias FunWithFlags.{Flag, Gate}

  @moduletag :ecto_persistence


  describe "put(flag_name, %Gate{}), for boolean, actor and group gates" do
    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      flag = %Flag{name: name, gates: [gate]}
      {:ok, name: name, gate: gate, flag: flag}
    end


    test "put() can change the value of a flag", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)

      PersiEcto.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [persisted_first_bool_gate]} = persisted} = PersiEcto.get(name)
      assert drop_timestamps(persisted_first_bool_gate) == drop_timestamps(first_bool_gate)
      assert %Gate{inserted_at: %DateTime{}, updated_at: %DateTime{}} = persisted_first_bool_gate
      assert persisted.last_modified_at == persisted_first_bool_gate.updated_at

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      PersiEcto.put(name, other_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [persisted_other_bool_gate]}} = PersiEcto.get(name)
      assert drop_timestamps(persisted_other_bool_gate) == drop_timestamps(other_bool_gate)
      assert %Gate{inserted_at: %DateTime{}, updated_at: %DateTime{}} = persisted_other_bool_gate
      assert persisted.last_modified_at == persisted_other_bool_gate.updated_at
      refute match? {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}}, PersiEcto.get(name)

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      PersiEcto.put(name, actor_gate)
      {:ok, result} = PersiEcto.get(name)
      assert %Flag{name: ^name} = result
      assert length(result.gates) == 2
      assert Enum.any?(result.gates, &(drop_timestamps(&1) == actor_gate))

      PersiEcto.put(name, first_bool_gate)
      {:ok, result2} = PersiEcto.get(name)
      assert %Flag{name: ^name} = result2
      assert length(result2.gates) == 2
      assert Enum.any?(result2.gates, &(drop_timestamps(&1) == first_bool_gate))
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      {:ok, result1} = PersiEcto.put(name, gate)
      assert %Flag{name: ^name} = result1
      assert [persisted_gate] = result1.gates
      assert drop_timestamps(persisted_gate) == gate

      {:ok, result2} = PersiEcto.put(name, gate)
      assert drop_timestamps(result2) == flag
    end

    test "put()'ing more gates will return an increasily updated flag", %{name: name, gate: gate} do
      {:ok, result1} = PersiEcto.put(name, gate)
      assert %Flag{name: ^name} = result1
      assert [persisted_gate] = result1.gates
      assert drop_timestamps(persisted_gate) == gate

      other_gate = %Gate{type: :actor, for: "string:asdf", enabled: true}
      {:ok, result2} = PersiEcto.put(name, other_gate)
      assert %Flag{name: ^name} = result2
      assert length(result2.gates) == 2
    end

    test "put() will UPSERT gates, inserting new ones and editing existing ones", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)

      PersiEcto.put(name, first_bool_gate)
      {:ok, result} = PersiEcto.get(name)
      assert %Flag{name: ^name} = result
      assert [persisted_gate] = result.gates
      assert drop_timestamps(persisted_gate) == first_bool_gate

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      PersiEcto.put(name, other_bool_gate)
      {:ok, result2} = PersiEcto.get(name)
      assert [pg2] = result2.gates
      assert drop_timestamps(pg2) == other_bool_gate

      first_actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      PersiEcto.put(name, first_actor_gate)
      expected_flag = make_expected_flag(name, [first_actor_gate, other_bool_gate])
      {:ok, result3} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result3) == expected_flag

      PersiEcto.put(name, first_bool_gate)
      expected_flag = make_expected_flag(name, [first_actor_gate, first_bool_gate])
      {:ok, result4} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result4) == expected_flag


      other_actor_gate = %Gate{type: :actor, for: "string:asd", enabled: true}
      PersiEcto.put(name, other_actor_gate)
      expected_flag = make_expected_flag(name, [other_actor_gate, first_actor_gate, first_bool_gate])
      {:ok, result5} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result5) == expected_flag

      first_actor_gate_disabled = %Gate{first_actor_gate | enabled: false}
      PersiEcto.put(name, first_actor_gate_disabled)
      expected_flag = make_expected_flag(name, [other_actor_gate, first_actor_gate_disabled, first_bool_gate])
      {:ok, result6} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result6) == expected_flag


      first_group_gate = %Gate{type: :group, for: "smurfs", enabled: true}
      PersiEcto.put(name, first_group_gate)
      expected_flag = make_expected_flag(name, [other_actor_gate, first_actor_gate_disabled, first_bool_gate, first_group_gate])
      {:ok, result7} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result7) == expected_flag

      other_group_gate = %Gate{type: :group, for: "gnomes", enabled: true}
      PersiEcto.put(name, other_group_gate)
      expected_flag = make_expected_flag(name, [other_actor_gate, first_actor_gate_disabled, first_bool_gate, other_group_gate, first_group_gate])
      {:ok, result8} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result8) == expected_flag

      first_group_gate_disabled = %Gate{first_group_gate | enabled: false}
      PersiEcto.put(name, first_group_gate_disabled)
      expected_flag = make_expected_flag(name, [other_actor_gate, first_actor_gate_disabled, first_bool_gate, other_group_gate, first_group_gate_disabled])
      {:ok, result9} = sort_db_result_gates(PersiEcto.get(name))
      assert drop_timestamps(result9) == expected_flag
    end

    test "put() updates the updated_at timestamp when upserting a gate", %{name: name} do
      bool_gate = %Gate{type: :boolean, enabled: true}
      {:ok, %Flag{gates: [first_persisted]}} = PersiEcto.put(name, bool_gate)
      assert %DateTime{} = first_persisted.updated_at

      Process.sleep(1_000)

      other_bool_gate = %Gate{type: :boolean, enabled: false}
      {:ok, %Flag{gates: [second_persisted]}} = PersiEcto.put(name, other_bool_gate)
      assert DateTime.compare(second_persisted.updated_at, first_persisted.updated_at) == :gt
    end
  end

# -----------------

  describe "put(flag_name, %Gate{}), for percentage_of_time gates" do
    setup do
      name = unique_atom()
      pot_gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      {:ok, name: name, pot_gate: pot_gate}
    end


    test "put() can change the value of a flag", %{name: name, pot_gate: pot_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)

      PersiEcto.put(name, pot_gate)
      {:ok, result1} = PersiEcto.get(name)
      assert [pg1] = result1.gates
      assert drop_timestamps(pg1) == pot_gate

      other_pot_gate = %Gate{pot_gate | for: 0.42}
      PersiEcto.put(name, other_pot_gate)
      {:ok, result2} = PersiEcto.get(name)
      assert [pg2] = result2.gates
      assert drop_timestamps(pg2) == other_pot_gate

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      PersiEcto.put(name, actor_gate)
      {:ok, result3} = PersiEcto.get(name)
      assert length(result3.gates) == 2

      PersiEcto.put(name, pot_gate)
      {:ok, result4} = PersiEcto.get(name)
      assert length(result4.gates) == 2
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, pot_gate: pot_gate} do
      {:ok, result} = PersiEcto.put(name, pot_gate)
      assert %Flag{name: ^name} = result
      assert [pg] = result.gates
      assert drop_timestamps(pg) == pot_gate
    end


    test "put()'ing more gates will return an increasily updated flag", %{name: name, pot_gate: pot_gate} do
      bool_gate = Gate.new(:boolean, false)
      {:ok, result1} = PersiEcto.put(name, bool_gate)
      assert [pg1] = result1.gates
      assert drop_timestamps(pg1) == bool_gate

      {:ok, result2} = PersiEcto.put(name, pot_gate)
      assert length(result2.gates) == 2
    end
  end

# -----------------

  describe "put(flag_name, %Gate{}), for percentage_of_actors gates" do
    setup do
      name = unique_atom()
      poa_gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      {:ok, name: name, poa_gate: poa_gate}
    end


    test "put() can change the value of a flag", %{name: name, poa_gate: poa_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)

      PersiEcto.put(name, poa_gate)
      {:ok, result1} = PersiEcto.get(name)
      assert [pg1] = result1.gates
      assert drop_timestamps(pg1) == poa_gate

      other_poa_gate = %Gate{poa_gate | for: 0.42}
      PersiEcto.put(name, other_poa_gate)
      {:ok, result2} = PersiEcto.get(name)
      assert [pg2] = result2.gates
      assert drop_timestamps(pg2) == other_poa_gate

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      PersiEcto.put(name, actor_gate)
      {:ok, result3} = PersiEcto.get(name)
      assert length(result3.gates) == 2

      PersiEcto.put(name, poa_gate)
      {:ok, result4} = PersiEcto.get(name)
      assert length(result4.gates) == 2
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, poa_gate: poa_gate} do
      {:ok, result} = PersiEcto.put(name, poa_gate)
      assert %Flag{name: ^name} = result
      assert [pg] = result.gates
      assert drop_timestamps(pg) == poa_gate
    end


    test "put()'ing more gates will return an increasily updated flag", %{name: name, poa_gate: poa_gate} do
      bool_gate = Gate.new(:boolean, false)
      {:ok, result1} = PersiEcto.put(name, bool_gate)
      assert [pg1] = result1.gates
      assert drop_timestamps(pg1) == bool_gate

      {:ok, result2} = PersiEcto.put(name, poa_gate)
      assert length(result2.gates) == 2
    end
  end

# -----------------

  describe "delete(flag_name, %Gate{}), for boolean, actor and group gates" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, flag} = PersiEcto.put(name, actor_gate)
      {:ok, ^flag} = PersiEcto.get(name)

      # Extract persisted gates with timestamps
      [persisted_actor, persisted_bool, persisted_group] = flag.gates

      {:ok, name: name, flag: flag, bool_gate: persisted_bool, group_gate: persisted_group, actor_gate: persisted_actor}
    end


    test "delete(flag_name, gate) can change the value of a flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, actor_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name, bool_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = PersiEcto.delete(name, %Gate{type: :actor, for: "I'm not really there", enabled: false})
    end
  end

# -----------------

  describe "delete(flag_name, %Gate{}), for percentage_of_time gates" do
    setup do
      name = unique_atom()

      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      pot_gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, actor_gate)
      {:ok, flag} = PersiEcto.put(name, pot_gate)
      {:ok, ^flag} = PersiEcto.get(name)

      # Extract persisted gates with timestamps
      [persisted_actor, persisted_bool, persisted_group, persisted_pot] = flag.gates

      {:ok, name: name, flag: flag, bool_gate: persisted_bool, group_gate: persisted_group, actor_gate: persisted_actor, pot_gate: persisted_pot}
    end


    test "delete(flag_name, gate) can change the value of a flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^pot_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = PersiEcto.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, pot_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^pot_gate]}} = PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, pot_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors",
          %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, pot_gate)
    end
  end

# -----------------

  describe "delete(flag_name, %Gate{}), for percentage_of_actors gates" do
    setup do
      name = unique_atom()

      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      poa_gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}

      expected_flag = %Flag{name: name, gates: sort_gates_by_type([bool_gate, group_gate, actor_gate, poa_gate])}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, actor_gate)
      {:ok, flag} = PersiEcto.put(name, poa_gate)
      assert drop_timestamps(flag) == expected_flag
      {:ok, ^flag} = PersiEcto.get(name)

      # Extract persisted gates with timestamps
      [persisted_actor, persisted_bool, persisted_group, persisted_poa] = flag.gates

      {:ok, name: name, flag: flag, bool_gate: persisted_bool, group_gate: persisted_group, actor_gate: persisted_actor, poa_gate: persisted_poa}
    end


    test "delete(flag_name, gate) can change the value of a flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^poa_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = PersiEcto.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, poa_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^poa_gate]}} = PersiEcto.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = PersiEcto.delete(name, poa_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors",
          %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.delete(name, poa_gate)
    end
  end

# -----------------


  describe "delete(flag_name)" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}

      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = PersiEcto.put(name, group_gate)
      {:ok, flag} = PersiEcto.put(name, actor_gate)
      {:ok, ^flag} = PersiEcto.get(name)

      # Extract persisted gates with timestamps
      [persisted_actor, persisted_bool, persisted_group] = flag.gates

      {:ok, name: name, flag: flag, bool_gate: persisted_bool, group_gate: persisted_group, actor_gate: persisted_actor}
    end


    test "delete(flag_name) will remove the flag from Redis (it will appear as an empty flag, which is the default when
          getting unknown flag name)", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)

      PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end


    test "delete(flag_name) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
    end


    test "deleting()'ing the same flag multiple time is a no-op. In other words: deleting a flag is idempotent
          and it's safe to try and delete non-present flags without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = PersiEcto.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.delete(name)
    end
  end

# -------------

  describe "get(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert {:ok, %Flag{name: ^name, gates: []}} = PersiEcto.get(name)
      PersiEcto.put(name, gate)
      {:ok, result} = PersiEcto.get(name)
      assert %Flag{name: ^name} = result
      assert [persisted_gate] = result.gates
      assert drop_timestamps(persisted_gate) == gate
    end
  end


  describe "all_flags() returns the tuple {:ok, list} with all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = PersiEcto.all_flags()
    end

    test "with saved flags it returns a list of flags" do
      name1 = unique_atom()
      g_1a = Gate.new(:actor, "the actor", true)
      g_1b = Gate.new(:boolean, false)
      g_1c = Gate.new(:group, :horses, true)
      PersiEcto.put(name1, g_1a)
      PersiEcto.put(name1, g_1b)
      PersiEcto.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:actor, "another actor", true)
      g_2b = Gate.new(:boolean, false)
      PersiEcto.put(name2, g_2a)
      PersiEcto.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      PersiEcto.put(name3, g_3a)

      {:ok, result} = PersiEcto.all_flags()
      assert 3 = length(result)

      result_without_timestamps = Enum.map(result, &drop_timestamps/1)

      for flag <- [
        %Flag{name: name1, gates: [g_1a, g_1b, g_1c]},
        %Flag{name: name2, gates: [g_2a, g_2b]},
        %Flag{name: name3, gates: [g_3a]}
      ] do
        assert flag in result_without_timestamps
      end
    end
  end


  describe "all_flag_names() returns the tuple {:ok, list}, with the names of all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = PersiEcto.all_flag_names()
    end

    test "with saved flags it returns a list of flag names" do

      name1 = unique_atom()
      g_1a = Gate.new(:boolean, false)
      g_1b = Gate.new(:actor, "the actor", true)
      g_1c = Gate.new(:group, :horses, true)
      PersiEcto.put(name1, g_1a)
      PersiEcto.put(name1, g_1b)
      PersiEcto.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:boolean, false)
      g_2b = Gate.new(:actor, "another actor", true)
      PersiEcto.put(name2, g_2a)
      PersiEcto.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      PersiEcto.put(name3, g_3a)

      {:ok, result} = PersiEcto.all_flag_names()
      assert 3 = length(result)

      for name <- [name1, name2, name3] do
        assert name in result
      end
    end
  end


  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = PersiEcto.get(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = PersiEcto.get(name)
    end
  end


  defp sort_gates_by_type(gates) do
    Enum.sort_by(gates, &(&1.type))
  end

  defp sort_flag_gates(flag) do
    %{flag | gates: Enum.sort(flag.gates)}
  end

  defp sort_db_result_gates({:ok, flag}) do
    {:ok, sort_flag_gates(flag)}
  end

  # DBs may return the rows in undeterministic orders.
  # This is fine in terms of functionality, but it makes is hard to write assertions.
  # This function is a way to de-flake some tests.
  #
  defp make_expected_flag(name, gates) do
    sort_flag_gates(%Flag{name: name, gates: gates})
  end

  defp drop_timestamps(%Gate{} = gate) do
    %{gate | inserted_at: nil, updated_at: nil}
  end

  defp drop_timestamps(%Flag{} = flag) do
    %{flag | last_modified_at: nil, gates: Enum.map(flag.gates, &drop_timestamps/1)}
  end
end
