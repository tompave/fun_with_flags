defmodule FunWithFlags.SimpleStoreTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.SimpleStore
  alias FunWithFlags.{Flag, Gate, Config}

  @persistence Config.persistence_adapter()

  setup_all do
    on_exit(__MODULE__, fn() -> clear_test_db() end)
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
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.lookup(name)

      SimpleStore.put(name, gate)
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = SimpleStore.lookup(name)

      gate2 = %Gate{gate | enabled: false}
      SimpleStore.put(name, gate2)
      assert {:ok, %Flag{name: ^name, gates: [^gate2]}} = SimpleStore.lookup(name)
      refute match? {:ok, %Flag{name: ^name, gates: [^gate]}}, SimpleStore.lookup(name)
    end

    test "put() returns the tuple {:ok, %Flag{}}", %{name: name, gate: gate, flag: flag} do
      assert {:ok, ^flag} = SimpleStore.put(name, gate)
    end

    @tag :telemetry
    test "when writing succeeds, put() will publish a telemetry event", %{name: name, gate: gate} do
      event = [:fun_with_flags, :persistence, :write]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.put(name, gate)

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: ^gate}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when writing fails, put() will publish an error telemetry event", %{name: name, gate: gate} do
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [put: fn(^name, ^gate) -> {:error, error_reason} end]) do
        assert {:error, ^error_reason} = SimpleStore.put(name, gate)
        assert called(@persistence.put(name, gate))
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: ^gate, error: ^error_reason, original_event: :write}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "delete(flag_name, gate)" do
    setup do
      group_gate = %Gate{type: :group, for: "muggles", enabled: false}
      bool_gate = %Gate{type: :boolean, enabled: true}
      name = unique_atom()

      SimpleStore.put(name, bool_gate)
      SimpleStore.put(name, group_gate)
      {:ok, flag} = SimpleStore.lookup(name)
      assert %Flag{name: ^name, gates: [^bool_gate, ^group_gate]} = flag

      {:ok, name: name, bool_gate: bool_gate, group_gate: group_gate}
    end

    test "delete(flag_name, gate) can change the value of a flag", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = SimpleStore.lookup(name)

      SimpleStore.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = SimpleStore.lookup(name)
      SimpleStore.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.lookup(name)
    end

    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = SimpleStore.delete(name, bool_gate)
    end

    test "deleting is safe and idempotent", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = SimpleStore.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: [^group_gate]}} = SimpleStore.delete(name, bool_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.delete(name, group_gate)
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.delete(name, group_gate)
    end

    @tag :telemetry
    test "when deleting succeeds, delete() will publish a telemetry event", %{name: name, bool_gate: gate} do
      event = [:fun_with_flags, :persistence, :delete_gate]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.delete(name, gate)

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: ^gate}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when deleting fails, delete() will publish an error telemetry event", %{name: name, bool_gate: gate} do
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [delete: fn(^name, ^gate) -> {:error, error_reason} end]) do
        assert {:error, ^error_reason} = SimpleStore.delete(name, gate)
        assert called(@persistence.delete(name, gate))
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: ^gate, error: ^error_reason, original_event: :delete_gate}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "delete(flag_name)" do
    setup do
      group_gate = %Gate{type: :group, for: "muggles", enabled: false}
      bool_gate = %Gate{type: :boolean, enabled: true}
      name = unique_atom()

      SimpleStore.put(name, bool_gate)
      SimpleStore.put(name, group_gate)
      {:ok, flag} = SimpleStore.lookup(name)
      assert %Flag{name: ^name, gates: [^bool_gate, ^group_gate]} = flag

      {:ok, name: name, bool_gate: bool_gate, group_gate: group_gate}
    end

    test "delete(flag_name) will reset all the flag gates", %{name: name, bool_gate: bool_gate, group_gate: group_gate} do
      assert {:ok, %Flag{name: ^name, gates: [^bool_gate, ^group_gate]}} = SimpleStore.lookup(name)

      SimpleStore.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.lookup(name)
    end

    test "delete(flag_name, gate) returns the tuple {:ok, %Flag{}}", %{name: name} do
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.delete(name)
    end

    test "deleting is safe and idempotent", %{name: name} do
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.delete(name)
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.delete(name)
    end

    @tag :telemetry
    test "when deleting succeeds, delete() will publish a telemetry event", %{name: name} do
      event = [:fun_with_flags, :persistence, :delete_flag]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.delete(name)

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: nil}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when deleting fails, delete() will publish an error telemetry event", %{name: name} do
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [delete: fn(^name) -> {:error, error_reason} end]) do
        assert {:error, ^error_reason} = SimpleStore.delete(name)
        assert called(@persistence.delete(name))
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: nil, error: ^error_reason, original_event: :delete_flag}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "lookup(flag_name)" do
    test "looking up an undefined flag returns an flag with no gates" do
      name = unique_atom()
      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.lookup(name)
    end

    test "looking up a saved flag returns the flag" do
      name = unique_atom()
      gate = %Gate{type: :boolean, enabled: true}

      assert {:ok, %Flag{name: ^name, gates: []}} = SimpleStore.lookup(name)
      SimpleStore.put(name, gate)
      assert {:ok, %Flag{name: ^name, gates: [^gate]}} = SimpleStore.lookup(name)
    end

    @tag :telemetry
    test "when reading succeeds, lookup() will publish a telemetry event" do
      name = unique_atom()
      event = [:fun_with_flags, :persistence, :read]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.lookup(name)

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: nil}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when reading fails, lookup() will publish an error telemetry event" do
      name = unique_atom()
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [get: fn(^name) -> {:error, error_reason} end]) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          SimpleStore.lookup(name)
        end
        assert called(@persistence.get(name))
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^name, gate: nil, error: ^error_reason, original_event: :read}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "all_flags() returns the tuple {:ok, list} with all the flags" do
    test "with no saved flags it returns an empty list" do
      clear_test_db()
      assert {:ok, []} = SimpleStore.all_flags()
    end

    test "with saved flags it returns a list of flags" do
      clear_test_db()

      name1 = unique_atom()
      g_1a = Gate.new(:actor, "the actor", true)
      g_1b = Gate.new(:boolean, false)
      g_1c = Gate.new(:group, :horses, true)
      SimpleStore.put(name1, g_1a)
      SimpleStore.put(name1, g_1b)
      SimpleStore.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:actor, "another actor", true)
      g_2b = Gate.new(:boolean, false)
      SimpleStore.put(name2, g_2a)
      SimpleStore.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      SimpleStore.put(name3, g_3a)

      {:ok, result} = SimpleStore.all_flags()
      assert 3 = length(result)

      for flag <- [
        %Flag{name: name1, gates: [g_1a, g_1b, g_1c]},
        %Flag{name: name2, gates: [g_2a, g_2b]},
        %Flag{name: name3, gates: [g_3a]}
      ] do
        assert flag in result
      end
    end

    @tag :telemetry
    test "when loading all flags succeeds, all_flags() will publish a telemetry event" do
      event = [:fun_with_flags, :persistence, :read_all_flags]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.all_flags()

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: nil, gate: nil}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when loading all flags fails, all_flags() will publish an error telemetry event" do
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [all_flags: fn() -> {:error, error_reason} end]) do
        assert {:error, ^error_reason} = SimpleStore.all_flags()
        assert called(@persistence.all_flags())
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: nil, gate: nil, error: ^error_reason, original_event: :read_all_flags}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "all_flag_names() returns the tuple {:ok, list}, with the names of all the flags" do
    test "with no saved flags it returns an empty list" do
      clear_test_db()
      assert {:ok, []} = SimpleStore.all_flag_names()
    end

    test "with saved flags it returns a list of flag names" do
      clear_test_db()

      name1 = unique_atom()
      g_1a = Gate.new(:boolean, false)
      g_1b = Gate.new(:actor, "the actor", true)
      g_1c = Gate.new(:group, :horses, true)
      SimpleStore.put(name1, g_1a)
      SimpleStore.put(name1, g_1b)
      SimpleStore.put(name1, g_1c)

      name2 = unique_atom()
      g_2a = Gate.new(:boolean, false)
      g_2b = Gate.new(:actor, "another actor", true)
      SimpleStore.put(name2, g_2a)
      SimpleStore.put(name2, g_2b)

      name3 = unique_atom()
      g_3a = Gate.new(:boolean, true)
      SimpleStore.put(name3, g_3a)

      {:ok, result} = SimpleStore.all_flag_names()
      assert 3 = length(result)

      for name <- [name1, name2, name3] do
        assert name in result
      end
    end

    @tag :telemetry
    test "when loading all flag names succeeds, all_flag_names() will publish a telemetry event" do
      event = [:fun_with_flags, :persistence, :read_all_flag_names]
      ref = :telemetry_test.attach_event_handlers(self(), [event])

      SimpleStore.all_flag_names()

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: nil, gate: nil}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    @tag :telemetry
    test "when loading all flag names fails, all_flag_names() will publish an error telemetry event" do
      event = [:fun_with_flags, :persistence, :error]
      ref = :telemetry_test.attach_event_handlers(self(), [event])
      error_reason = "mocked error"

      with_mock(@persistence, [], [all_flag_names: fn() -> {:error, error_reason} end]) do
        assert {:error, ^error_reason} = SimpleStore.all_flag_names()
        assert called(@persistence.all_flag_names())
      end

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        %{flag_name: nil, gate: nil, error: ^error_reason, original_event: :read_all_flag_names}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end


  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag" do
      name = unique_atom()
      FunWithFlags.disable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: false}]}} = SimpleStore.lookup(name)
    end

    test "looking up an enabled flag" do
      name = unique_atom()
      FunWithFlags.enable(name)
      assert {:ok, %Flag{name: ^name, gates: [%Gate{type: :boolean, enabled: true}]}} = SimpleStore.lookup(name)
    end
  end


  describe "in case of Persistent store failure" do
    @tag :redis_persistence
    test "it raises an error (redis)" do
      alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis
      name = unique_atom()

      with_mock(PersiRedis, [], get: fn(^name) -> {:error, "mocked error"} end) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          SimpleStore.lookup(name)
        end
        assert called(PersiRedis.get(name))
        assert {:error, "mocked error"} = PersiRedis.get(name)
      end
    end

    @tag :redis_persistence
    test "in case of redis connection error" do
      alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis
      name = unique_atom()

      with_mock(Redix, [], command: fn(_conn, ["HGETALL", _]) -> {:error, %Redix.ConnectionError{reason: :nxdomain}} end) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          SimpleStore.lookup(name)
        end
        assert called(Redix.command(:_, :_))
        assert {:error, "Redis Connection Error: nxdomain"} = PersiRedis.get(name)
      end
    end

    @tag :redis_persistence
    test "in case of redis semantic error" do
      alias FunWithFlags.Store.Persistent.Redis, as: PersiRedis
      name = unique_atom()

      with_mock(Redix, [], command: fn(_conn, ["HGETALL", _]) -> {:error, %Redix.Error{message: "wrong type"}} end) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          SimpleStore.lookup(name)
        end
        assert called(Redix.command(:_, :_))
        assert {:error, "Redis Error: wrong type"} = PersiRedis.get(name)
      end
    end

    @tag :ecto_persistence
    test "it raises an error (ecto)" do
      alias FunWithFlags.Store.Persistent.Ecto, as: PersiEcto
      name = unique_atom()

      with_mock(PersiEcto, [], get: fn(^name) -> {:error, "mocked error"} end) do
        assert_raise RuntimeError, "Can't load feature flag", fn() ->
          SimpleStore.lookup(name)
        end
        assert called(PersiEcto.get(name))
        assert {:error, "mocked error"} = PersiEcto.get(name)
      end
    end
  end
end
