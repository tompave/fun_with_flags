defmodule FunWithFlags.FlagTest do
  use FunWithFlags.TestCase, async: true

  alias FunWithFlags.{Flag, Gate}

  describe "new(name)" do
    test "it returns a new flag struct" do
      assert %Flag{name: :pear, gates: []} = Flag.new(:pear)
    end
  end

  describe "enabled?(flag) - only flag parameter, no options" do
    test "it returns true if the flag only has a boolean value = true" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, true)]}
      assert Flag.enabled?(flag)
    end

    test "it returns false if the flag only has a boolean value = false" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, false)]}
      refute Flag.enabled?(flag)
    end

    test "it returns false if the flag doesn't have any gate" do
      flag = %Flag{name: :banana, gates: []}
      refute Flag.enabled?(flag)
    end

    test "if the flag has an enabled boolean gate and a percentage_of_time gate, it returns true" do
      flag = %Flag{
        name: :banana,
        gates: [Gate.new(:boolean, true), Gate.new(:percentage_of_time, 0.999999999)]
      }

      assert Flag.enabled?(flag)

      flag = %Flag{
        name: :banana,
        gates: [Gate.new(:boolean, true), Gate.new(:percentage_of_time, 0.000000001)]
      }

      assert Flag.enabled?(flag)
    end

    @tag :flaky
    test "if the flag has a disabled boolean gate and a percentage_of_time gate, it rolls a dice" do
      flag = %Flag{
        name: :banana,
        gates: [Gate.new(:boolean, false), Gate.new(:percentage_of_time, 0.999999999)]
      }

      assert Flag.enabled?(flag)

      flag = %Flag{
        name: :banana,
        gates: [Gate.new(:boolean, false), Gate.new(:percentage_of_time, 0.000000001)]
      }

      refute Flag.enabled?(flag)
    end

    @tag :flaky
    test "if the flag has a percentage_of_time gate only, it rolls a dice" do
      flag = %Flag{name: :banana, gates: [Gate.new(:percentage_of_time, 0.999999999)]}
      assert Flag.enabled?(flag)

      flag = %Flag{name: :banana, gates: [Gate.new(:percentage_of_time, 0.000000001)]}
      refute Flag.enabled?(flag)
    end

    test "other gates are ignored" do
      data = %{mario: "luigi", actor_id: "peach"}

      gates = [
        Gate.new(:actor, data, false),
        Gate.new(:boolean, true),
        Gate.new(:group, :parrots, false),
        Gate.new(:percentage_of_actors, 0.00000001)
      ]

      flag = %Flag{name: :banana, gates: gates}
      assert Flag.enabled?(flag)
    end
  end

  describe "enabled?(flag, for: item)" do
    alias FunWithFlags.TestUser

    setup do
      john = %TestUser{id: 42, email: "john@snow.nw", groups: [:starks, :nights_watch]}
      arya = %TestUser{id: 151, email: "arya@stark.wf", groups: [:starks, :nameless_men]}
      {:ok, john: john, arya: arya}
    end

    # Actor.Percentage.score(john, :warging)
    # 0.381500244140625
    # Actor.Percentage.score(arya, :warging)
    # 0.4635467529296875

    test "with no gates, checking for an actor default to false", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: []}

      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "with only boolean gates, checking with an item falls back to the boolean gate", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, true)]}

      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, false)]}

      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "with only actor gates, the actors are checked and otherwise it defaults to false", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{name: :pear, gates: [Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{
        name: :pear,
        gates: [Gate.new(:actor, john, false), Gate.new(:actor, arya, true)]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "with only group gates, the groups are checked and otherwise it defaults to false", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{name: :pear, gates: [Gate.new(:group, :nights_watch, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:group, :nights_watch, false)]}
      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    @tag :flaky
    test "with only a percentage_of_time gate, the gate is checked", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:percentage_of_time, 0.999999999)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:percentage_of_time, 0.000000001)]}
      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "with only a percentage_of_actors gate, the gate is checked and only true for the actors with the right score",
         %{john: john, arya: arya} do
      flag = %Flag{name: :warging, gates: [Gate.new(:percentage_of_actors, 0.37)]}
      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{name: :warging, gates: [Gate.new(:percentage_of_actors, 0.39)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{name: :warging, gates: [Gate.new(:percentage_of_actors, 0.47)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "when the checked item belongs to multiple conflicting group gates, DISABLED gates take precence",
         %{john: john, arya: arya} do
      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:group, :nights_watch, false),
          Gate.new(:group, :starks, true)
        ]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      # default
      refute Flag.enabled?(flag)

      # invert the order
      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:group, :starks, true),
          Gate.new(:group, :nights_watch, false)
        ]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      # default
      refute Flag.enabled?(flag)
    end

    # precedence ----------------------------------------------------

    test "an actor gate takes precendence over the boolean gate, when enabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, false), Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over the boolean gate, when disabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, true), Gate.new(:actor, john, false)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    @tag :flaky
    test "an actor gate takes precendence over the percentage_of_time gate, when enabling", %{
      john: john,
      arya: arya
    } do
      mostly_disabled = Gate.new(:percentage_of_time, 0.000000001)
      flag = %Flag{name: :pear, gates: [mostly_disabled, Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    @tag :flaky
    test "an actor gate takes precendence over the percentage_of_time gate, when disabling", %{
      john: john,
      arya: arya
    } do
      mostly_enabled = Gate.new(:percentage_of_time, 0.999999999)
      flag = %Flag{name: :pear, gates: [mostly_enabled, Gate.new(:actor, john, false)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over the percentage_of_actors gate, when enabling", %{
      john: john,
      arya: arya
    } do
      # disabled for both
      gate = Gate.new(:percentage_of_actors, 0.2)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over the percentage_of_actors gate, when disabling", %{
      john: john,
      arya: arya
    } do
      # enabled for both
      gate = Gate.new(:percentage_of_actors, 0.8)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:actor, john, false)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "a group gate takes precendence over the boolean gate, when enabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{
        name: :pear,
        gates: [Gate.new(:boolean, false), Gate.new(:group, :nameless_men, true)]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "a group gate takes precendence over the boolean gate, when disabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{
        name: :pear,
        gates: [Gate.new(:boolean, true), Gate.new(:group, :nameless_men, false)]
      }

      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    @tag :flaky
    test "a group gate takes precendence over the percentage_of_time gate, when enabling", %{
      john: john,
      arya: arya
    } do
      mostly_disabled = Gate.new(:percentage_of_time, 0.000000001)
      flag = %Flag{name: :pear, gates: [mostly_disabled, Gate.new(:group, :nameless_men, true)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    @tag :flaky
    test "a group gate takes precendence over the percentage_of_time gate, when disabling", %{
      john: john,
      arya: arya
    } do
      mostly_enabled = Gate.new(:percentage_of_time, 0.999999999)
      flag = %Flag{name: :pear, gates: [mostly_enabled, Gate.new(:group, :nameless_men, false)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    test "a group gate takes precendence over the percentage_of_actors gate, when enabling", %{
      john: john,
      arya: arya
    } do
      # disabled for both
      gate = Gate.new(:percentage_of_actors, 0.2)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:group, :nameless_men, true)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "a group gate takes precendence over the percentage_of_actors gate, when disabling", %{
      john: john,
      arya: arya
    } do
      # enabled for both
      gate = Gate.new(:percentage_of_actors, 0.8)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:group, :nameless_men, false)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over a group gate, when enabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:group, :starks, false),
          Gate.new(:actor, john, true)
        ]
      }

      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over a group gate, when disabling", %{
      john: john,
      arya: arya
    } do
      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:group, :starks, true),
          Gate.new(:actor, john, false)
        ]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      # default
      refute Flag.enabled?(flag)
    end

    @tag :flaky
    test "a boolean gate takes precendence over the percentage_of_time gate, when enabling", %{
      john: john,
      arya: arya
    } do
      mostly_disabled = Gate.new(:percentage_of_time, 0.000000001)
      flag = %Flag{name: :pear, gates: [mostly_disabled, Gate.new(:boolean, true)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    @tag :flaky
    test "a boolean gate does NOT take precendence over the percentage_of_time gate, when disabling",
         %{john: john, arya: arya} do
      mostly_enabled = Gate.new(:percentage_of_time, 0.999999999)
      flag = %Flag{name: :pear, gates: [mostly_enabled, Gate.new(:boolean, false)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    test "a boolean gate takes precendence over the percentage_of_actors gate, when enabling", %{
      john: john,
      arya: arya
    } do
      # disabled for both
      gate = Gate.new(:percentage_of_actors, 0.2)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:boolean, true)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end

    test "a boolean gate does NOT take precendence over the percentage_of_actors gate, when disabling",
         %{john: john, arya: arya} do
      # enabled for both
      gate = Gate.new(:percentage_of_actors, 0.8)
      flag = %Flag{name: :pear, gates: [gate, Gate.new(:boolean, false)]}
      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "precendence order", %{john: john, arya: arya} do
      # precedence order:
      # - actor,
      # - then groups,
      # - then booleans,
      # - then, only if bool is disabled or missing:
      #    - percentage_of_time (if present, applies with or without actors in the enabled?() call)
      #   or:
      #    - percentage_of_actors (only if an actor is provided)

      # score with :warging flag = 0.122283935546875
      other_actor = %{actor_id: "a valid actor, but not an enabled one"}

      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:actor, john, true),
          Gate.new(:group, :starks, false),
          # mostly disabled
          Gate.new(:percentage_of_time, 0.000000001)
        ]
      }

      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag, for: other_actor)
      assert Flag.enabled?(flag)

      flag = %Flag{
        name: :pear,
        gates: [
          Gate.new(:boolean, false),
          Gate.new(:actor, john, false),
          Gate.new(:group, :starks, true),
          # mostly enabled
          Gate.new(:percentage_of_time, 0.999999999)
        ]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag, for: other_actor)
      assert Flag.enabled?(flag)

      flag = %Flag{
        name: :warging,
        gates: [
          Gate.new(:boolean, false),
          Gate.new(:actor, john, false),
          Gate.new(:group, :starks, true),
          # enabled for all
          Gate.new(:percentage_of_actors, 0.8)
        ]
      }

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag, for: other_actor)
      refute Flag.enabled?(flag)

      flag = %Flag{
        name: :warging,
        gates: [
          Gate.new(:boolean, false),
          Gate.new(:actor, john, true),
          Gate.new(:group, :starks, true),
          # disabled for all
          Gate.new(:percentage_of_actors, 0.05)
        ]
      }

      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag, for: other_actor)
      refute Flag.enabled?(flag)

      flag = %Flag{
        name: :warging,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:actor, john, true),
          Gate.new(:group, :starks, false),
          # disabled for all
          Gate.new(:percentage_of_actors, 0.05)
        ]
      }

      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag, for: other_actor)
      assert Flag.enabled?(flag)
    end

    # invalid "for" and corner cases ----------------------------------------------------

    test "checking a flag with a non-actor just fall sback to the boolean gate if there are no other gates" do
      flag = %Flag{name: :strawberry, gates: [Gate.new(:boolean, true)]}
      # does not implement Actor nor Group
      item = [1, 2]
      assert Flag.enabled?(flag, for: item)

      flag = %Flag{name: :strawberry, gates: [Gate.new(:boolean, false)]}
      refute Flag.enabled?(flag, for: item)
    end

    test "checking a flag with a non-actor just falls back to the boolean gate if there are group gates" do
      flag = %Flag{
        name: :strawberry,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:group, :mammals, false)
        ]
      }

      # does not implement Actor nor Group
      item = [1, 2]
      assert Flag.enabled?(flag, for: item)
    end

    test "checking a flag with a non-actor raises an exception if there are actor gates" do
      flag = %Flag{
        name: :strawberry,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:group, :mammals, false),
          Gate.new(:actor, "strings are actors too", false)
        ]
      }

      # does not implement Actor nor Group
      item = [1, 2]

      assert_raise Protocol.UndefinedError, fn ->
        Flag.enabled?(flag, for: item)
      end
    end

    test "checking a flag with a non-actor raises an exception if there are percentage_of_actors gates that are checked" do
      flag = %Flag{
        name: :strawberry,
        gates: [
          # since this is false, the %-of-actors gate will be checked
          Gate.new(:boolean, false),
          Gate.new(:group, :mammals, true),
          Gate.new(:percentage_of_actors, 0.5)
        ]
      }

      # does not implement Actor nor Group
      item = [1, 2]

      assert_raise Protocol.UndefinedError, fn ->
        Flag.enabled?(flag, for: item)
      end
    end

    test "checking a flag with a non-actor just stops at the boolean gate if that is enabled" do
      flag = %Flag{
        name: :strawberry,
        gates: [
          # since this is true, the %-of-actors gate will not be checked
          Gate.new(:boolean, true),
          Gate.new(:group, :mammals, true),
          Gate.new(:percentage_of_actors, 0.5)
        ]
      }

      # does not implement Actor nor Group
      item = [1, 2]

      assert Flag.enabled?(flag, for: item)
    end

    test "checking a flag with an actor but non-group will just ignore the group gates, if present" do
      flag = %Flag{
        name: :strawberry,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:actor, "strings are actors too", false)
        ]
      }

      # does not implement Group, but it implements Actor
      item = "a binary"
      assert Flag.enabled?(flag, for: item)

      flag = %Flag{
        name: :strawberry,
        gates: [
          Gate.new(:boolean, true),
          Gate.new(:group, :mammals, false),
          Gate.new(:actor, "strings are actors too", false)
        ]
      }

      assert Flag.enabled?(flag, for: item)
    end
  end
end
