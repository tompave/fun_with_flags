defmodule FunWithFlags.FlagTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.{Flag,Gate}

  describe "new(name)" do
    test "it returns a new flag struct" do
      assert %Flag{name: :pear, gates: []} = Flag.new(:pear)
    end
  end


  describe "enabled?(flag) - only flag parameter, no options" do
    test "it returns true if the flag has a boolean value = true" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, true)]}
      assert Flag.enabled?(flag)
    end

    test "it returns false if the flag has a boolean value = false" do
      flag = %Flag{name: :banana, gates: [Gate.new(:boolean, false)]}
      refute Flag.enabled?(flag)
    end

    test "it returns false if the flag doesn't have any gate" do
      flag = %Flag{name: :banana, gates: []}
      refute Flag.enabled?(flag)
    end

    test "other gates are ignored" do
      data = %{mario: "luigi", actor_id: "peach"}
      gates = [Gate.new(:actor, data, false), Gate.new(:boolean, true), Gate.new(:group, :parrots, false)]
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


    test "with no gates, checking for an actor default to false", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: []}

      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "with only boolean gates, checking with an item falls back to the boolean gate", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, true)]}

      assert Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, false)]}

      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "with only actor gates, the actors are checked and otherwise it defaults to false", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:actor, john, false), Gate.new(:actor, arya, true)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "with only group gates, the groups are checked and otherwise it defaults to false", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:group, :nights_watch, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [Gate.new(:group, :nights_watch, false)]}
      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "when the checked item belongs to multiple conflicting group gates, DISABLED gates take precence", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [
        Gate.new(:group, :nights_watch, false),
        Gate.new(:group, :starks, true),
      ]}

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag) # default


      # invert the order
      flag = %Flag{name: :pear, gates: [
        Gate.new(:group, :starks, true),
        Gate.new(:group, :nights_watch, false),
      ]}

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag) # default
    end


    # precedence ----------------------------------------------------

    test "an actor gate takes precendence over the boolean gate, when enabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, false), Gate.new(:actor, john, true)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over the boolean gate, when disabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, true), Gate.new(:actor, john, false)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end


    test "a group gate takes precendence over the boolean gate, when enabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, false), Gate.new(:group, :nameless_men, true)]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "a group gate takes precendence over the boolean gate, when disabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [Gate.new(:boolean, true), Gate.new(:group, :nameless_men, false)]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)
    end


    test "an actor gate takes precendence over a group gate, when enabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [
        Gate.new(:group, :starks, false),
        Gate.new(:actor, john, true)
      ]}
      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end

    test "an actor gate takes precendence over a group gate, when disabling", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [
        Gate.new(:group, :starks, true),
        Gate.new(:actor, john, false)
      ]}
      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag) # default
    end


    test "precedence order: actor, then groups, then booleans", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: [
        Gate.new(:boolean, true),
        Gate.new(:actor, john, true),
        Gate.new(:group, :starks, false),
      ]}

      assert Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      assert Flag.enabled?(flag)

      flag = %Flag{name: :pear, gates: [
        Gate.new(:boolean, false),
        Gate.new(:actor, john, false),
        Gate.new(:group, :starks, true),
      ]}

      refute Flag.enabled?(flag, for: john)
      assert Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "checking a flag with a non-actor just fallsback to the boolean gate if there are no other gates" do
      flag = %Flag{name: :strawberry, gates: [Gate.new(:boolean, true)]}
      item = [1,2] # does not implement Actor nor Group
      assert Flag.enabled?(flag, for: item)

      flag = %Flag{name: :strawberry, gates: [Gate.new(:boolean, false)]}
      refute Flag.enabled?(flag, for: item)
    end

    test "checking a flag with a non-actor just falls back to the boolean gate if there are group gates" do
      flag = %Flag{name: :strawberry, gates: [
        Gate.new(:boolean, true),
        Gate.new(:group, :mammals, false),
      ]}
      item = [1,2] # does not implement Actor nor Group
      assert Flag.enabled?(flag, for: item)
    end

    test "checking a flag with a non-actor raises an exception if there are actor gates" do
      flag = %Flag{name: :strawberry, gates: [
        Gate.new(:boolean, true),
        Gate.new(:group, :mammals, false),
        Gate.new(:actor, "strings are actors too", false),
      ]}
      item = [1,2] # does not implement Actor nor Group

      assert_raise Protocol.UndefinedError, fn() ->
        Flag.enabled?(flag, for: item)
      end
    end

    test "checking a flag with an actor but non-group will just ignore the group gates, if present" do
      flag = %Flag{name: :strawberry, gates: [
        Gate.new(:boolean, true),
        Gate.new(:actor, "strings are actors too", false),
      ]}
      item = "a binary" # does not implement Group, but it implements Actor
      assert Flag.enabled?(flag, for: item)

      flag = %Flag{name: :strawberry, gates: [
        Gate.new(:boolean, true),
        Gate.new(:group, :mammals, false),
        Gate.new(:actor, "strings are actors too", false),
      ]}

      assert Flag.enabled?(flag, for: item)
    end
  end
end
