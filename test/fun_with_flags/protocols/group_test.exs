defmodule FunWithFlags.GroupTest do
  use FunWithFlags.TestCase, async: true

  alias FunWithFlags.{Group, TestUser}

  setup do
    user1 = %TestUser{id: 1, email: "bruce@wayne.com"}
    user2 = %TestUser{id: 2, email: "clark@kent.com"}
    {:ok, user1: user1, user2: user2}
  end

  test "in?(term, group_name) returns true if the term is in the group", %{user1: user1} do
    assert Group.in?(user1, :admin)
  end

  test "in?(term, group_name) returns false if the term is not in the group", %{
    user1: user1,
    user2: user2
  } do
    refute Group.in?(user2, :admin)
    refute Group.in?(user1, :undefined_name)
  end

  describe "anything can be an actor, e.g. Maps" do
    test "a map that declares the right group" do
      map = %{group: :pug_lovers}
      assert Group.in?(map, :pug_lovers)
    end

    test "a map that does NOT declare the right group" do
      map = %{group: :cat_owner}
      refute Group.in?(map, :pug_lovers)
      refute Group.in?(%{}, :pug_lovers)
    end
  end

  describe "the fallback Any implementation" do
    test "returns false for any argument, so that nothing is in any group" do
      refute Group.in?(123, :group_name)
      refute Group.in?([], :group_name)
    end
  end
end
