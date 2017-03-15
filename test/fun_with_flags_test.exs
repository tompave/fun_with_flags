defmodule FunWithFlagsTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  doctest FunWithFlags

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end

  describe "enabled?(name)" do
    test "it returns false for non existing feature flags" do
      flag_name = unique_atom()
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns false for a disabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns true for an enabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)
    end

    test "if the store returns anything other than {:ok, _}, it returns false" do
      name = unique_atom()
      {:ok, true} = FunWithFlags.enable(name)
      assert true == FunWithFlags.enabled?(name)

      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> {:error, "mocked"} end) do
        assert false == FunWithFlags.enabled?(name)
      end
    end


    test "if the store raises an error, it lets it bubble up" do
      name = unique_atom()
      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> raise(RuntimeError, "mocked exception") end) do
        assert_raise RuntimeError, "mocked exception", fn() ->
          FunWithFlags.enabled?(name)
        end
      end
    end
  end


  describe "enabled?(name, for: actor)" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp"}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db"}
      {:ok, scrooge: scrooge, donald: donald, flag_name: unique_atom()}
    end

    test "it returns false for non existing feature flags", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an enabled actor even though the flag doesn't have a general value,
          while other actors fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an enabled actor even though the flag is disabled, while other
          actors fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns false for a disabled actor even though the flag is enabled, while other
          actors default to the default (true)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name, for_actor: donald)
      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be enabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name)
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      FunWithFlags.enable(flag_name, for_actor: donald)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be disabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name)
      FunWithFlags.disable(flag_name, for_actor: scrooge)
      FunWithFlags.disable(flag_name, for_actor: donald)
      assert FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end
  end


  describe "enabling and disabling flags" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp"}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db"}
      {:ok, scrooge: scrooge, donald: donald, flag_name: unique_atom()}
    end


    test "flags can be enabled and disabled with simple boolean gates", %{flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)

      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
    end


    test "flags can be enabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
    end


    test "flags can be disabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.disable(flag_name, for_actor: donald)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end


    test "enabling always returns the tuple {:ok, true} on success", %{flag_name: flag_name} do
      assert {:ok, true} = FunWithFlags.enable(flag_name)
      assert {:ok, true} = FunWithFlags.enable(flag_name)
      assert {:ok, true} = FunWithFlags.enable(flag_name, for_actor: "a string")
    end

    test "disabling always returns the tuple {:ok, false} on success", %{flag_name: flag_name} do
      assert {:ok, false} = FunWithFlags.disable(flag_name)
      assert {:ok, false} = FunWithFlags.disable(flag_name)
      assert {:ok, false} = FunWithFlags.disable(flag_name, for_actor: "a string")
    end
  end


  describe "looking up a flag after a delay (indirectly test the cache TTL, if present)" do
    alias FunWithFlags.Config

    test "the flag value is still set even after the TTL of the cache (regardless of the cache being present)" do
      flag_name = unique_atom()

      assert false == FunWithFlags.enabled?(flag_name)
      {:ok, true} = FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)

      timetravel by: (Config.cache_ttl + 10_000) do
        assert true == FunWithFlags.enabled?(flag_name)
      end
    end
  end
end
