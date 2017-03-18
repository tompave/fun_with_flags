defmodule FunWithFlags.FlagTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.{Flag,Gate}

  describe "new(name)" do
    test "it returns a new flag struct" do
      assert %Flag{name: :pear, gates: []} = Flag.new(:pear)
    end
  end


  describe "from_redis(name, [gate, data])" do
    test "with empty data it returns an empty flag" do
      assert %Flag{name: :kiwi, gates: []} = Flag.from_redis(:kiwi, [])
    end

    test "with boolean gate data it returns a simple boolean flag" do
      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: true}]} =
          Flag.from_redis(:kiwi, ["boolean", "true"])
      )

      assert(
        %Flag{name: :kiwi, gates: [%Gate{type: :boolean, enabled: false}]} =
          Flag.from_redis(:kiwi, ["boolean", "false"])
      )
    end

    test "with more than one gate it returns a composite flag" do
      flag = %Flag{name: :peach, gates: [
        %Gate{type: :boolean, enabled: true},
        %Gate{type: :actor, for: "user:123", enabled: false},
      ]}
      assert ^flag = Flag.from_redis(:peach, ["boolean", "true", "actor/user:123", "false"])

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
      assert ^flag = Flag.from_redis(:apricot, raw_redis_data)
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
      gates = [Gate.new(:actor, data, false), Gate.new(:boolean, true)]
      flag = %Flag{name: :banana, gates: gates}
      assert Flag.enabled?(flag)
    end
  end



  describe "enabled?(flag, for: actor)" do
    alias FunWithFlags.TestUser

    setup do
      john = %TestUser{id: 42, email: "john@snow.nw"}
      arya = %TestUser{id: 151, email: "arya@stark.wf"}
      {:ok, john: john, arya: arya}
    end


    test "with no gates, checking for an actor default to false", %{john: john, arya: arya} do
      flag = %Flag{name: :pear, gates: []}

      refute Flag.enabled?(flag, for: john)
      refute Flag.enabled?(flag, for: arya)
      refute Flag.enabled?(flag)
    end


    test "with only boolean gates, checking for an actor falls back to the boolean gate", %{john: john, arya: arya} do
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
  end
end
