defmodule FunWithFlags.GateTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Gate
  alias FunWithFlags.TestUser

  describe "new() for boolean gates" do
    test "new(:boolean, true|false) returns a new Boolean Gate" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Gate.new(:boolean, true)
      assert %Gate{type: :boolean, for: nil, enabled: false} = Gate.new(:boolean, false)
    end

    test "new(:actor, actor, true|false) returns a new Actor Gate" do
      user = %TestUser{id: 234, email: "pineapple@pine.apple.com" }

      assert %Gate{type: :actor, for: "user:234", enabled: true} = Gate.new(:actor, user, true)
      assert %Gate{type: :actor, for: "user:234", enabled: false} = Gate.new(:actor, user, false)

      map = %{actor_id: "hello", foo: "bar"}
      assert %Gate{type: :actor, for: "map:hello", enabled: true} = Gate.new(:actor, map, true)
      assert %Gate{type: :actor, for: "map:hello", enabled: false} = Gate.new(:actor, map, false)
    end

    test "new(:actor, ...) with a non-actor raises an exception" do
      assert_raise Protocol.UndefinedError, fn() ->
        Gate.new(:actor, :not_a_valid_actor, true)
      end
    end
  end


  describe "from_redis() returns a Gate struct" do
    test "with boolean data" do
      assert %Gate{type: :boolean, for: nil, enabled: true} = Gate.from_redis(["boolean", "true"])
      assert %Gate{type: :boolean, for: nil, enabled: false} = Gate.from_redis(["boolean", "false"])
    end

    test "with actor data" do
      assert %Gate{type: :actor, for: "anything", enabled: true} = Gate.from_redis(["actor/anything", "true"])
      assert %Gate{type: :actor, for: "really:123", enabled: false} = Gate.from_redis(["actor/really:123", "false"])
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
      gandalf = %TestUser{id: 42, email: "gandalf@travels.com" }

      gate = %Gate{type: :boolean, for: nil, enabled: true}
      assert {:ok, true} = Gate.enabled?(gate, for: gandalf)

      gate = %Gate{type: :boolean, for: nil, enabled: false}
      assert {:ok, false} = Gate.enabled?(gate, for: gandalf)
    end
  end


  describe "enabled?(gate, for: actor)" do
    setup do
      chip = %TestUser{id: 1, email: "chip@rescuerangers.com" }
      dale = %TestUser{id: 2, email: "dale@rescuerangers.com" }
      gate = Gate.new(:actor, chip, true)
      {:ok, gate: gate, chip: chip, dale: dale}
    end

    test "without the [for: actor] option it raises an exception", %{gate: gate} do
      assert_raise FunctionClauseError, fn() ->
        Gate.enabled?(gate)
      end
    end

    test "for an enabled gate, it returns {:ok, true} for the associated
          actor and :ignore for other actors", %{gate: gate, chip: chip, dale: dale} do
      assert {:ok, true} = Gate.enabled?(gate, for: chip)
      assert :ignore = Gate.enabled?(gate, for: dale)
    end

    test "for a disabled gate, it returns {:ok, false} for the associated
          actor and :ignore for other actors", %{gate: gate, chip: chip, dale: dale} do
      gate = %Gate{gate | enabled: false}

      assert {:ok, false} = Gate.enabled?(gate, for: chip)
      assert :ignore = Gate.enabled?(gate, for: dale)
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
  end
end
