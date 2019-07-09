defmodule FunWithFlags.Store.Persistent.InMemoryTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils

  alias FunWithFlags.Store.Persistent.InMemory
  alias FunWithFlags.{Flag, Gate}

  @moduletag :in_memory_persistence

  setup do
    {:ok, pid} = InMemory.start_link()

    on_exit(fn ->
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    :ok
  end

  describe "put(flag_name, %Gate{}), for boolean, actor and group gates" do
    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      flag = %Flag{name: name, gates: [gate]}
      {:ok, name: name, gate: gate, flag: flag}
    end


    test "put() can change the value of a flag", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)

      InMemory.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}} = InMemory.get(name)

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      InMemory.put(name, other_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_bool_gate]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}}, InMemory.get(name)

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      InMemory.put(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^other_bool_gate]}} = InMemory.get(name)

      InMemory.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^first_bool_gate]}} = InMemory.get(name)
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = InMemory.put(name, gate)
      assert {:ok, ^flag} = InMemory.put(name, gate)
    end

    test "put()'ing more gates will return an increasily updated flag", %{name: name, gate: gate} do
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = InMemory.put(name, gate)

      other_gate = %Gate{type: :actor, for: "string:asdf", enabled: true}
      assert {:ok, %Flag{name: ^name, gates: [^other_gate, ^gate]}} = InMemory.put(name, other_gate)
    end

    test "put() will UPSERT gates, inserting new ones and editing existing ones", %{name: name, gate: first_bool_gate} do
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)

      InMemory.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}} = InMemory.get(name)

      other_bool_gate = %Gate{first_bool_gate | enabled: false}
      InMemory.put(name, other_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_bool_gate]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^first_bool_gate]}}, InMemory.get(name)

      first_actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      InMemory.put(name, first_actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_actor_gate, ^other_bool_gate]}} = InMemory.get(name)

      InMemory.put(name, first_bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^first_actor_gate, ^first_bool_gate]}} = InMemory.get(name)


      other_actor_gate = %Gate{type: :actor, for: "string:asd", enabled: true}
      InMemory.put(name, other_actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate, ^first_bool_gate]}} = InMemory.get(name)

      first_actor_gate_disabled = %Gate{first_actor_gate | enabled: false}
      InMemory.put(name, first_actor_gate_disabled)
      assert {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate_disabled, ^first_bool_gate]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate, ^first_bool_gate]}}, InMemory.get(name)


      first_group_gate = %Gate{type: :group, for: "smurfs", enabled: true}
      InMemory.put(name, first_group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate_disabled, ^first_bool_gate, ^first_group_gate]}} = InMemory.get(name)

      other_group_gate = %Gate{type: :group, for: "gnomes", enabled: true}
      InMemory.put(name, other_group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate_disabled, ^first_bool_gate, ^other_group_gate, ^first_group_gate]}} = InMemory.get(name)

      first_group_gate_disabled = %Gate{first_group_gate | enabled: false}
      InMemory.put(name, first_group_gate_disabled)
      assert {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate_disabled, ^first_bool_gate, ^other_group_gate, ^first_group_gate_disabled]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^other_actor_gate, ^first_actor_gate_disabled, ^first_bool_gate, ^other_group_gate, ^first_group_gate]}}, InMemory.get(name)
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
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)

      InMemory.put(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^pot_gate]}} = InMemory.get(name)

      other_pot_gate = %Gate{pot_gate | for: 0.42}
      InMemory.put(name, other_pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_pot_gate]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^pot_gate]}}, InMemory.get(name)

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      InMemory.put(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^other_pot_gate]}} = InMemory.get(name)

      InMemory.put(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^pot_gate]}} = InMemory.get(name)
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, pot_gate: pot_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^pot_gate]}} = InMemory.put(name, pot_gate)
    end


    test "put()'ing more gates will return an increasily updated flag", %{name: name, pot_gate: pot_gate} do
      bool_gate = Gate.new(:boolean, false)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.put(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^pot_gate]}} = InMemory.put(name, pot_gate)
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
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)

      InMemory.put(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^poa_gate]}} = InMemory.get(name)

      other_poa_gate = %Gate{poa_gate | for: 0.42}
      InMemory.put(name, other_poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^other_poa_gate]}} = InMemory.get(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^poa_gate]}}, InMemory.get(name)

      actor_gate = %Gate{type: :actor, for: "string:qwerty", enabled: true}
      InMemory.put(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^other_poa_gate]}} = InMemory.get(name)

      InMemory.put(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^poa_gate]}} = InMemory.get(name)
    end


    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, poa_gate: poa_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^poa_gate]}} = InMemory.put(name, poa_gate)
    end


    test "put()'ing more gates will return an increasily updated flag", %{name: name, poa_gate: poa_gate} do
      bool_gate = Gate.new(:boolean, false)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.put(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^poa_gate]}} = InMemory.put(name, poa_gate)
    end
  end

# -----------------

  describe "delete(flag_name, %Gate{}), for boolean, actor and group gates" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate])}

      {:ok, %Flag{name: ^name}} = InMemory.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, group_gate)
      {:ok, ^flag} = InMemory.put(name, actor_gate)
      {:ok, ^flag} = InMemory.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate}
    end


    test "delete(flag_name, gate) can change the value of a flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)

      InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = InMemory.get(name)

      InMemory.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate]}} = InMemory.get(name)

      InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, actor_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.delete(name, bool_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate]}} = InMemory.delete(name, %Gate{type: :actor, for: "I'm not really there", enabled: false})
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

      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate, pot_gate])}

      {:ok, %Flag{name: ^name}} = InMemory.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, group_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, actor_gate)
      {:ok, ^flag} = InMemory.put(name, pot_gate)
      {:ok, ^flag} = InMemory.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate}
    end


    test "delete(flag_name, gate) can change the value of a flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = InMemory.get(name)

      InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^pot_gate]}} = InMemory.get(name)

      InMemory.delete(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = InMemory.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, pot_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^pot_gate]}} = InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, pot_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors",
          %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, pot_gate: pot_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^pot_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, pot_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, pot_gate)
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

      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate, poa_gate])}

      {:ok, %Flag{name: ^name}} = InMemory.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, group_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, actor_gate)
      {:ok, ^flag} = InMemory.put(name, poa_gate)
      {:ok, ^flag} = InMemory.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate}
    end


    test "delete(flag_name, gate) can change the value of a flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = InMemory.get(name)

      InMemory.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^poa_gate]}} = InMemory.get(name)

      InMemory.delete(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate]}} = InMemory.get(name)
    end


    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, poa_gate)
    end


    test "deleting()'ing more gates will return an increasily simpler flag",
         %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate, ^poa_gate]}} = InMemory.delete(name, actor_gate)
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = InMemory.delete(name, poa_gate)
    end


    test "deleting()'ing the same gate multiple time is a no-op. In other words: deleting a gate is idempotent
          and it's safe to try and delete non-present gates without errors",
          %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate, poa_gate: poa_gate} do

      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate, ^poa_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, poa_gate)
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.delete(name, poa_gate)
    end
  end

# -----------------


  describe "delete(flag_name)" do
    setup do
      name = unique_atom()
      bool_gate = %Gate{type: :boolean, enabled: false}
      group_gate = %Gate{type: :group, for: "admins", enabled: true}
      actor_gate = %Gate{type: :actor, for: "string_actor", enabled: true}
      flag = %Flag{name: name, gates: sort_gates([bool_gate, group_gate, actor_gate])}

      {:ok, %Flag{name: ^name}} = InMemory.put(name, bool_gate)
      {:ok, %Flag{name: ^name}} = InMemory.put(name, group_gate)
      {:ok, ^flag} = InMemory.put(name, actor_gate)
      {:ok, ^flag} = InMemory.get(name)

      {:ok, name: name, flag: flag, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate}
    end


    test "delete(flag_name) will remove the flag from Redis (it will appear as an empty flag, which is the default when
          getting unknown flag name)", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)

      InMemory.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)
    end


    test "delete(flag_name) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.delete(name)
    end


    test "deleting()'ing the same flag multiple time is a no-op. In other words: deleting a flag is idempotent
          and it's safe to try and delete non-present flags without errors", %{name: name, bool_gate: bool_gate, group_gate: group_gate, actor_gate: actor_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^actor_gate, ^bool_gate, ^group_gate]}} = InMemory.get(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.delete(name)
    end
  end

# -------------

  describe "get(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert {:ok, %Flag{name: ^name, gates: []}} = InMemory.get(name)
      InMemory.put(name, gate)
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = InMemory.get(name)
    end
  end


  describe "all_flags() returns the tuple {:ok, list} with all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = InMemory.all_flags()
    end

    test "with saved flags it returns a list of flags" do
      name1 = unique_atom()
      g_1a = Gate.new(:actor, "the actor", true)
      g_1b = Gate.new(:boolean, false)
      g_1c = Gate.new(:group, :horses, true)
      InMemory.put(name1, g_1a)
      InMemory.put(name1, g_1b)
      InMemory.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:actor, "another actor", true)
      g_2b = Gate.new(:boolean, false)
      InMemory.put(name2, g_2a)
      InMemory.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      InMemory.put(name3, g_3a)

      {:ok, result} = InMemory.all_flags()
      assert 3 = length(result)

      for flag <- [
        %Flag{name: name1, gates: [g_1a, g_1b, g_1c]},
        %Flag{name: name2, gates: [g_2a, g_2b]},
        %Flag{name: name3, gates: [g_3a]}
      ] do
        assert flag in result
      end
    end
  end


  describe "all_flag_names() returns the tuple {:ok, list}, with the names of all the flags" do
    test "with no saved flags it returns an empty list" do
      assert {:ok, []} = InMemory.all_flag_names()
    end

    test "with saved flags it returns a list of flag names" do

      name1 = unique_atom()
      g_1a = Gate.new(:boolean, false)
      g_1b = Gate.new(:actor, "the actor", true)
      g_1c = Gate.new(:group, :horses, true)
      InMemory.put(name1, g_1a)
      InMemory.put(name1, g_1b)
      InMemory.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:boolean, false)
      g_2b = Gate.new(:actor, "another actor", true)
      InMemory.put(name2, g_2a)
      InMemory.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      InMemory.put(name3, g_3a)

      {:ok, result} = InMemory.all_flag_names()
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
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = InMemory.get(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = InMemory.get(name)
    end
  end


  defp sort_gates(gates) do
    Enum.sort_by(gates, &(&1.type))
  end
end
