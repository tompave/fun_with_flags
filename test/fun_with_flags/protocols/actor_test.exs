defmodule FunWithFlags.ActorTest do
  use ExUnit.Case, async: true

  alias FunWithFlags.{Actor, TestUser}

  setup do
    user = %TestUser{id: 1, email: "bruce@wayne.com"}
    {:ok, user: user}
  end

  test "id(actor) returns always the same string for the same actor", %{user: user} do
    assert "user:1" = Actor.id(user)
    assert "user:1" = Actor.id(user)
    assert "user:1" = Actor.id(user)
  end

  test "different actors produce different strings", %{user: user} do
    user2 = %TestUser{id: 2, email: "alfred@wayne.com"}
    user3 = %TestUser{id: 3, email: "dick@wayne.com"}

    assert "user:1" = Actor.id(user)
    assert "user:2" = Actor.id(user2)
    assert "user:3" = Actor.id(user3)
  end

  describe "anything can be an actor, e.g. Maps" do
    test "map with an id" do
      map = %{actor_id: 42}
      assert "map:42" = Actor.id(map)
    end

    test "map without an id" do
      map = %{foo: 42}
      assert "map:ev5wm33phiqdimt5" = Actor.id(map)
    end
  end
end
