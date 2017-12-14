defmodule FunWithFlags.Store.PersistentTest do
  use FunWithFlags.TestCase, async: true
  alias FunWithFlags.Store.Persistent
  alias FunWithFlags.Config

  @tag :redis_persistence
  test "adapter() returns the Redis adapter" do
    assert Persistent.Redis = Config.persistence_adapter()
  end

  @tag :ecto_persistence
  test "adapter() returns the Ecto adapter" do
    assert Persistent.Ecto = Config.persistence_adapter()
  end
end
