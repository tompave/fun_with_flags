defmodule FunWithFlags.SimpleStoreTest do
  use ExUnit.Case, async: true
  import FunWithFlags.TestUtils

  alias FunWithFlags.SimpleStore
  alias FunWithFlags.{Flag, Gate}

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end


  describe "put(flag_name, %Gate{})" do
    setup do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}
      flag = %Flag{name: name, gates: [gate]}
      {:ok, name: name, gate: gate, flag: flag}
    end

    test "put() can change the value of a flag", %{name: name, gate: gate} do
      assert %Flag{name: ^name, gates: []} = SimpleStore.lookup(name)

      SimpleStore.put(name, gate)
      assert %Flag{name: ^name, gates: [^gate]} = SimpleStore.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      SimpleStore.put(name, gate2)
      assert %Flag{name: ^name, gates: [^gate2]} = SimpleStore.lookup(name)
      refute match? %Flag{name: ^name, gates: [^gate]}, SimpleStore.lookup(name)
    end

    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, ^flag} = SimpleStore.put(name, gate)
    end
  end


  describe "lookup(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert %Flag{name: ^name, gates: []} = SimpleStore.lookup(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert %Flag{name: ^name, gates: []} = SimpleStore.lookup(name)
      SimpleStore.put(name, gate)
      assert %Flag{name: ^name, gates: [^gate]} = SimpleStore.lookup(name)
    end  
  end


  # describe "integration: enable and disable with the top-level API" do
  #   test "looking up a disabled flag returns false" do
  #     flag_name = unique_atom()
  #     FunWithFlags.disable(flag_name)
  #     assert false == SimpleStore.lookup(flag_name)
  #   end
  #   test "looking up an enabled flag returns true" do
  #     flag_name = unique_atom()
  #     FunWithFlags.enable(flag_name)
  #     assert true == SimpleStore.lookup(flag_name)
  #   end
  # end
end
