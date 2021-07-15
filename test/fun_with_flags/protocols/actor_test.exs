defmodule FunWithFlags.ActorTest do
  use FunWithFlags.TestCase, async: true

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
      assert "map:F0107BBFB094FC97376CFC461E33ABF5" = Actor.id(map)
    end
  end

  describe "score(actor, flag_name), auto-delegated to a private worker module" do
    import FunWithFlags.TestUtils

    test "it returns a float" do
      map = %{actor_id: 42}
      assert is_float(Actor.Percentage.score(map, :foobar))
    end

    test "the float is between 0.0 and 1.0" do
      for _ <- 0..100 do
        map = %{actor_id: random_string()}
        score = Actor.Percentage.score(map, :foobar)
        assert score <= 1.0
        assert score >= 0.0
      end
    end

    test "the same actor-flag combination always produces the same score", %{user: user} do
      score = Actor.Percentage.score(user, :foobar)

      for _ <- 1..100 do
        assert ^score = Actor.Percentage.score(user, :foobar)
      end
    end

    test "different actors produce different scores", %{user: user} do
      user2 = %TestUser{id: 2, email: "alfred@wayne.com"}
      user3 = %TestUser{id: 3, email: "dick@wayne.com"}

      assert Actor.Percentage.score(user, :foobar) != Actor.Percentage.score(user2, :foobar)
      assert Actor.Percentage.score(user, :foobar) != Actor.Percentage.score(user3, :foobar)
      assert Actor.Percentage.score(user2, :foobar) != Actor.Percentage.score(user3, :foobar)
    end

    test "the same actor produces different scores with different flags", %{user: user} do
      assert Actor.Percentage.score(user, :one) != Actor.Percentage.score(user, :two)
      assert Actor.Percentage.score(user, :one) != Actor.Percentage.score(user, :three)
      assert Actor.Percentage.score(user, :two) != Actor.Percentage.score(user, :three)
      assert Actor.Percentage.score(user, :two) != Actor.Percentage.score(user, :four)
      assert Actor.Percentage.score(user, :four) != Actor.Percentage.score(user, :one)
      assert Actor.Percentage.score(user, :four) != Actor.Percentage.score(user, :three)
    end
  end
end
