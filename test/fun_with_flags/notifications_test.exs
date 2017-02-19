defmodule FunWithFlags.NotificationsTest do
  use ExUnit.Case, async: true
  import FunWithFlags.TestUtils

  alias FunWithFlags.Notifications


  describe "unique_id()" do
    test "it returns a string" do
      assert is_binary(Notifications.unique_id())
    end

    test "it always returns the same ID for the GenServer" do
      assert Notifications.unique_id() == Notifications.unique_id()
    end

    test "the ID changes if the GenServer restarts" do
      a = Notifications.unique_id()
      kill_process(Notifications)
      :timer.sleep(1)
      refute a == Notifications.unique_id()
    end
  end
end
