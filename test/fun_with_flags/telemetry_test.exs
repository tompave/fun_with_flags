defmodule FunWithFlags.TelemetryTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Telemetry, as: FWFTel
  alias FunWithFlags.Gate

  @moduletag :telemetry

  describe "emit_persistence_event()" do
    test "with a success tuple" do
      result = {:ok, "something"}
      event_name = :some_event
      flag_name = :some_flag
      gate = %Gate{type: :boolean, enabled: true}

      ref = :telemetry_test.attach_event_handlers(self(), [[:fun_with_flags, :persistence, event_name]])

      assert ^result = FWFTel.emit_persistence_event(result, event_name, flag_name, gate)

      assert_received {
        [:fun_with_flags, :persistence, ^event_name],
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^flag_name, gate: ^gate}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end

    test "with an error tuple" do
      result = {:error, "some error"}
      event_name = :some_event
      flag_name = :some_flag
      gate = %Gate{type: :boolean, enabled: true}

      ref = :telemetry_test.attach_event_handlers(self(), [[:fun_with_flags, :persistence, :error]])

      assert ^result = FWFTel.emit_persistence_event(result, event_name, flag_name, gate)

      assert_received {
        [:fun_with_flags, :persistence, :error],
        ^ref,
        %{system_time: time_value},
        %{flag_name: ^flag_name, gate: ^gate, error: "some error", original_event: ^event_name}
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end

  describe "do_send_event()" do
    test "it emits an event with the right prefix and measures" do
      metadata = %{foo: "bar"}
      event = [:foo, :bar, :monkey]

      ref = :telemetry_test.attach_event_handlers(self(), [event])

      assert :ok = FWFTel.do_send_event(event, metadata)

      assert_received {
        ^event,
        ^ref,
        %{system_time: time_value},
        ^metadata
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end
end
