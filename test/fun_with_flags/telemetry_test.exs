defmodule FunWithFlags.TelemetryTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.Telemetry, as: FWFTel

  @moduletag :telemetry

  describe "persistence_event()" do
    test "it emits an event with the right prefix and measures" do
      metadata = %{foo: "bar"}
      event = :monkey

      ref = :telemetry_test.attach_event_handlers(self(), [[:fun_with_flags, :persistence, event]])

      assert :ok = FWFTel.persistence_event(event, metadata)

      assert_received {
        [:fun_with_flags, :persistence, ^event],
        ^ref,
        %{system_time: time_value},
        ^metadata
      }

      assert is_integer(time_value)

      :telemetry.detach(ref)
    end
  end
end
