defmodule FunWithFlags.Store.PersistentTest do
  use ExUnit.Case, async: true
  alias FunWithFlags.Store.Persistent

  test "adapter() returns the Redis adapter" do
    assert FunWithFlags.Store.Persistent.Redis = Persistent.adapter
  end
end
