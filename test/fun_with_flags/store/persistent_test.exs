defmodule FunWithFlags.Store.PersistentTest do
  use FunWithFlags.TestCase, async: true
  alias FunWithFlags.Store.Persistent

  @tag :redis_persistence
  test "adapter() returns the Redis adapter" do
    assert FunWithFlags.Store.Persistent.Redis = Persistent.adapter
  end

  @tag :ecto_persistence
  test "adapter() returns the Ecto adapter" do
    assert FunWithFlags.Store.Persistent.Ecto = Persistent.adapter
  end
end
