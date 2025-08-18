defmodule FunWithFlags.TestUser do
  # A Test user
  defstruct [:id, :email, :name, groups: []]
end

defmodule FunWithFlags.TestOrg do
  # A Test organization
  defstruct [:id, :name, groups: []]
end

defimpl FunWithFlags.Actor, for: FunWithFlags.TestUser do
  def id(%{id: id}) do
    "user:#{id}"
  end
end

defimpl FunWithFlags.Group, for: FunWithFlags.TestUser do
  def in?(%{email: email}, "admin") do
    Regex.match?(~r/@wayne.com$/, email)
  end

  def in?(user, :admin) do
    __MODULE__.in?(user, "admin")
  end

  # Matches binaries or atoms.
  #
  def in?(%{groups: groups}, group) when is_list(groups) do
    group_s = to_string(group)
    Enum.any? groups, fn(g) -> to_string(g) == group_s end
  end
end

defimpl FunWithFlags.Actor, for: FunWithFlags.TestOrg do
  def id(%{id: id}) do
    "org:#{id}"
  end
end

defimpl FunWithFlags.Group, for: FunWithFlags.TestOrg do
  def in?(%{groups: groups}, group) do
    group_s = to_string(group)
    Enum.any? groups, fn(g) -> to_string(g) == group_s end
  end

  def in?(org, group) when is_atom(group) do
    __MODULE__.in?(org, to_string(group))
  end

  def in?(_, _), do: false
end
