defmodule FunWithFlags.Store.Persistent.EctoTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  # import Mock

  # alias FunWithFlags.Store.Persistent.Ecto, as: PersiEcto
  # alias FunWithFlags.{Config, Flag, Gate}
  # alias FunWithFlags.Notifications.PhoenixPubSub, as: NotifiPhoenix

  @moduletag :ecto_persistence

  setup_all do
    on_exit(__MODULE__, fn() -> clear_ecto_test_db() end)
    :ok
  end
end
