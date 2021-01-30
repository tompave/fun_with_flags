defmodule FunWithFlags.GateTest do
  use FunWithFlags.TestCase, async: true

  alias FunWithFlags.Gate
  alias FunWithFlags.TestUser

  describe "new()" do
    test "new(:boolean, true|false) returns a new Boolean Gate" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Gate.new(:boolean, true)
      assert %Gate{type: :boolean, for: nil, enabled: false} = Gate.new(:boolean, false)
    end

    test "new(:percentage_of_time, ratio_f) retrurns a PercentageOfTime gate" do
      assert %Gate{type: :percentage_of_time, for: 0.001, enabled: true} =
               Gate.new(:percentage_of_time, 0.001)

      assert %Gate{type: :percentage_of_time, for: 0.1, enabled: true} =
               Gate.new(:percentage_of_time, 0.1)

      assert %Gate{type: :percentage_of_time, for: 0.59, enabled: true} =
               Gate.new(:percentage_of_time, 0.59)

      assert %Gate{type: :percentage_of_time, for: 0.999, enabled: true} =
               Gate.new(:percentage_of_time, 0.999)
    end

    test "new(:percentage_of_time, ratio_f) with an invalid ratio raises an exception" do
      assert_raise FunWithFlags.Gate.InvalidTargetError, fn ->
        Gate.new(:percentage_of_time, 0.0)
      end

      assert_raise FunWithFlags.Gate.InvalidTargetError, fn ->
        Gate.new(:percentage_of_time, 1.0)
      end
    end

    test "new(:percentage_of_actors, ratio_f) retrurns a PercentageOfActors gate" do
      assert %Gate{type: :percentage_of_actors, for: 0.001, enabled: true} =
               Gate.new(:percentage_of_actors, 0.001)

      assert %Gate{type: :percentage_of_actors, for: 0.1, enabled: true} =
               Gate.new(:percentage_of_actors, 0.1)

      assert %Gate{type: :percentage_of_actors, for: 0.59, enabled: true} =
               Gate.new(:percentage_of_actors, 0.59)

      assert %Gate{type: :percentage_of_actors, for: 0.999, enabled: true} =
               Gate.new(:percentage_of_actors, 0.999)
    end

    test "new(:percentage_of_actors, ratio_f) with an invalid ratio raises an exception" do
      assert_raise FunWithFlags.Gate.InvalidTargetError, fn ->
        Gate.new(:percentage_of_actors, 0.0)
      end

      assert_raise FunWithFlags.Gate.InvalidTargetError, fn ->
        Gate.new(:percentage_of_actors, 1.0)
      end
    end

    test "new(:actor, actor, true|false) returns a new Actor Gate" do
      user = %TestUser{id: 234, email: "pineapple@pine.apple.com"}

      assert %Gate{type: :actor, for: "user:234", enabled: true} = Gate.new(:actor, user, true)
      assert %Gate{type: :actor, for: "user:234", enabled: false} = Gate.new(:actor, user, false)

      map = %{actor_id: "hello", foo: "bar"}
      assert %Gate{type: :actor, for: "map:hello", enabled: true} = Gate.new(:actor, map, true)
      assert %Gate{type: :actor, for: "map:hello", enabled: false} = Gate.new(:actor, map, false)
    end

    test "new(:actor, ...) with a non-actor raises an exception" do
      assert_raise Protocol.UndefinedError, fn ->
        Gate.new(:actor, :not_a_valid_actor, true)
      end
    end

    test "new(:group, group_name, true|false) returns a new Group Gate, with atoms" do
      assert %Gate{type: :group, for: "plants", enabled: true} = Gate.new(:group, :plants, true)

      assert %Gate{type: :group, for: "animals", enabled: false} =
               Gate.new(:group, :animals, false)
    end

    test "new(:group, group_name, true|false) returns a new Group Gate, with binaries" do
      assert %Gate{type: :group, for: "plants", enabled: true} = Gate.new(:group, "plants", true)

      assert %Gate{type: :group, for: "animals", enabled: false} =
               Gate.new(:group, "animals", false)
    end

    test "new(:group, ...) with a name that is not an atom or a binary raises an exception" do
      assert_raise FunWithFlags.Gate.InvalidGroupNameError, fn -> Gate.new(:group, 123, true) end

      assert_raise FunWithFlags.Gate.InvalidGroupNameError, fn ->
        Gate.new(:group, %{a: "map"}, false)
      end
    end
  end

  describe "enabled?(gate), for boolean gates" do
    test "without extra arguments, it simply checks the value of the gate" do
      gate = %Gate{type: :boolean, for: nil, enabled: true}
      assert {:ok, true} = Gate.enabled?(gate)

      gate = %Gate{type: :boolean, for: nil, enabled: false}
      assert {:ok, false} = Gate.enabled?(gate)
    end

    test "an optional [for: something] argument is ignored" do
      gandalf = %TestUser{id: 42, email: "gandalf@travels.com"}

      gate = %Gate{type: :boolean, for: nil, enabled: true}
      assert {:ok, true} = Gate.enabled?(gate, for: gandalf)

      gate = %Gate{type: :boolean, for: nil, enabled: false}
      assert {:ok, false} = Gate.enabled?(gate, for: gandalf)
    end
  end

  describe "enabled?(gate, for: actor)" do
    setup do
      chip = %TestUser{id: 1, email: "chip@rescuerangers.com"}
      dale = %TestUser{id: 2, email: "dale@rescuerangers.com"}
      gate = Gate.new(:actor, chip, true)
      {:ok, gate: gate, chip: chip, dale: dale}
    end

    test "without the [for: actor] option it raises an exception", %{gate: gate} do
      assert_raise FunctionClauseError, fn ->
        Gate.enabled?(gate)
      end
    end

    test "passing a nil actor option raises an exception (just because nil is not an Actor)", %{
      gate: gate
    } do
      assert_raise Protocol.UndefinedError, fn ->
        Gate.enabled?(gate, for: nil)
      end
    end

    test "for an enabled gate, it returns {:ok, true} for the associated
          actor and :ignore for other actors",
         %{gate: gate, chip: chip, dale: dale} do
      assert {:ok, true} = Gate.enabled?(gate, for: chip)
      assert :ignore = Gate.enabled?(gate, for: dale)
    end

    test "for a disabled gate, it returns {:ok, false} for the associated
          actor and :ignore for other actors",
         %{gate: gate, chip: chip, dale: dale} do
      gate = %Gate{gate | enabled: false}

      assert {:ok, false} = Gate.enabled?(gate, for: chip)
      assert :ignore = Gate.enabled?(gate, for: dale)
    end
  end

  describe "enabled?(gate, for: item), for Group gates" do
    setup do
      bruce = %TestUser{id: 1, email: "bruce@wayne.com"}
      clark = %TestUser{id: 2, email: "clark@kent.com"}
      gate = Gate.new(:group, :admin, true)
      {:ok, gate: gate, bruce: bruce, clark: clark}
    end

    test "without the [for: item] option it raises an exception", %{gate: gate} do
      assert_raise FunctionClauseError, fn ->
        Gate.enabled?(gate)
      end
    end

    test "for an enabled gate, it returns {:ok, true} for items that belongs to the group
          and :ignore for the others",
         %{gate: gate, bruce: bruce, clark: clark} do
      assert {:ok, true} = Gate.enabled?(gate, for: bruce)
      assert :ignore = Gate.enabled?(gate, for: clark)
    end

    test "for a disabled gate, it returns {:ok, false} for items that belongs to the group
          and :ignore for the others",
         %{gate: gate, bruce: bruce, clark: clark} do
      gate = %Gate{gate | enabled: false}

      assert {:ok, false} = Gate.enabled?(gate, for: bruce)
      assert :ignore = Gate.enabled?(gate, for: clark)
    end

    test "it always returns :ignore for items that do not implement the Group protocol
          (because of the fallback to Any)",
         %{gate: gate} do
      assert :ignore = Gate.enabled?(gate, for: nil)
      assert :ignore = Gate.enabled?(gate, for: "pompelmo")
      assert :ignore = Gate.enabled?(gate, for: [1, 2, 3])
      assert :ignore = Gate.enabled?(gate, for: {:a, "tuple"})
    end
  end

  describe "enabled?(gate), for PercentageOfTime gates" do
    @tag :flaky
    test "without extra arguments, it simply checks the value of the gate" do
      gate = %Gate{type: :percentage_of_time, for: 0.999999999, enabled: true}
      assert {:ok, true} = Gate.enabled?(gate)

      gate = %Gate{type: :percentage_of_time, for: 0.000000001, enabled: true}
      assert {:ok, false} = Gate.enabled?(gate)
    end

    @tag :flaky
    test "an optional [for: something] argument is ignored" do
      gandalf = %TestUser{id: 42, email: "gandalf@travels.com"}

      gate = %Gate{type: :percentage_of_time, for: 0.999999999, enabled: true}
      assert {:ok, true} = Gate.enabled?(gate, for: gandalf)

      gate = %Gate{type: :percentage_of_time, for: 0.000000001, enabled: true}
      assert {:ok, false} = Gate.enabled?(gate, for: gandalf)
    end
  end

  describe "enabled?(gate, for: actor, flag_name: atom), for PercentageOfActors gates" do
    setup do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      # with coconut: 0.7024383544921875
      gandalf = %TestUser{id: 42, email: "gandalf@travels.com"}
      # with coconut: 0.4715118408203125
      magneto = %TestUser{id: 2, email: "magneto@mutants.com"}
      {:ok, gate: gate, gandalf: gandalf, magneto: magneto}
    end

    test "without the [for: actor] option it raises an exception", %{gate: gate} do
      assert_raise KeyError, fn ->
        Gate.enabled?(gate, flag_name: :coconut)
      end
    end

    test "without the [flag_name: atom] option it raises an exception", %{
      gate: gate,
      gandalf: gandalf
    } do
      assert_raise KeyError, fn ->
        Gate.enabled?(gate, for: gandalf)
      end
    end

    test "passing a nil actor option raises an exception (just because nil is not an Actor)", %{
      gate: gate
    } do
      assert_raise Protocol.UndefinedError, fn ->
        Gate.enabled?(gate, for: nil, flag_name: :coconut)
      end
    end

    test "for actor-flags pairs with a score lower than the gate percentage it returns {:ok, true}, if the score is higher it returns {:ok, false}",
         %{gate: gate, gandalf: gandalf, magneto: magneto} do
      gate = %{gate | for: 0.5}
      assert {:ok, false} = Gate.enabled?(gate, for: gandalf, flag_name: :coconut)
      assert {:ok, true} = Gate.enabled?(gate, for: magneto, flag_name: :coconut)

      gate = %{gate | for: 0.46}
      assert {:ok, false} = Gate.enabled?(gate, for: gandalf, flag_name: :coconut)
      assert {:ok, false} = Gate.enabled?(gate, for: magneto, flag_name: :coconut)

      gate = %{gate | for: 0.703}
      assert {:ok, true} = Gate.enabled?(gate, for: gandalf, flag_name: :coconut)
      assert {:ok, true} = Gate.enabled?(gate, for: magneto, flag_name: :coconut)
    end
  end

  describe "boolean?(gate)" do
    test "with a boolean gate it returns true" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      assert Gate.boolean?(gate)
    end

    test "with an actor gate it returns false" do
      gate = %Gate{type: :actor, for: "salami", enabled: false}
      refute Gate.boolean?(gate)
    end

    test "with a group gate it returns false" do
      gate = %Gate{type: :group, for: "prosciutto", enabled: false}
      refute Gate.boolean?(gate)
    end

    test "with a percentage_of_time gate it returns false" do
      gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      refute Gate.boolean?(gate)
    end

    test "with a percentage_of_actors gate it returns false" do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      refute Gate.boolean?(gate)
    end
  end

  describe "actor?(gate)" do
    test "with an actor gate it returns true" do
      gate = %Gate{type: :actor, for: "salami", enabled: false}
      assert Gate.actor?(gate)
    end

    test "with a boolean gate it returns false" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      refute Gate.actor?(gate)
    end

    test "with a group gate it returns false" do
      gate = %Gate{type: :group, for: "prosciutto", enabled: false}
      refute Gate.actor?(gate)
    end

    test "with a percentage_of_time gate it returns false" do
      gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      refute Gate.actor?(gate)
    end

    test "with a percentage_of_actors gate it returns false" do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      refute Gate.actor?(gate)
    end
  end

  describe "group?(gate)" do
    test "with a group gate it returns true" do
      gate = %Gate{type: :group, for: "prosciutto", enabled: false}
      assert Gate.group?(gate)
    end

    test "with a boolean gate it returns false" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      refute Gate.group?(gate)
    end

    test "with an actor gate it returns false" do
      gate = %Gate{type: :actor, for: "salami", enabled: false}
      refute Gate.group?(gate)
    end

    test "with a percentage_of_time gate it returns false" do
      gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      refute Gate.group?(gate)
    end

    test "with a percentage_of_actors gate it returns false" do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      refute Gate.group?(gate)
    end
  end

  describe "percentage_of_time?(gate)" do
    test "with a percentage_of_time gate it returns true" do
      gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      assert Gate.percentage_of_time?(gate)
    end

    test "with a percentage_of_actors gate it returns false" do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      refute Gate.percentage_of_time?(gate)
    end

    test "with a boolean gate it returns false" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      refute Gate.percentage_of_time?(gate)
    end

    test "with an actor gate it returns false" do
      gate = %Gate{type: :actor, for: "salami", enabled: false}
      refute Gate.percentage_of_time?(gate)
    end

    test "with a group gate it returns false" do
      gate = %Gate{type: :group, for: "prosciutto", enabled: false}
      refute Gate.percentage_of_time?(gate)
    end
  end

  describe "percentage_of_actors?(gate)" do
    test "with a percentage_of_actors gate it returns true" do
      gate = %Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      assert Gate.percentage_of_actors?(gate)
    end

    test "with a percentage_of_time gate it returns false" do
      gate = %Gate{type: :percentage_of_time, for: 0.5, enabled: true}
      refute Gate.percentage_of_actors?(gate)
    end

    test "with a boolean gate it returns false" do
      gate = %Gate{type: :boolean, for: nil, enabled: false}
      refute Gate.percentage_of_actors?(gate)
    end

    test "with an actor gate it returns false" do
      gate = %Gate{type: :actor, for: "salami", enabled: false}
      refute Gate.percentage_of_actors?(gate)
    end

    test "with a group gate it returns false" do
      gate = %Gate{type: :group, for: "prosciutto", enabled: false}
      refute Gate.percentage_of_actors?(gate)
    end
  end
end
