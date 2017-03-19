defmodule FunWithFlags.TestUser do
  # A Test user
  defstruct [:id, :email, :name, groups: []]
end

defimpl FunWithFlags.Actor, for: FunWithFlags.TestUser do
  def id(%{id: id}) do
    "user:#{id}"
  end
end


defimpl FunWithFlags.Group, for: FunWithFlags.TestUser do
  def in?(%{email: email}, :admin) do
    Regex.match?(~r/@wayne.com$/, email)
  end

  def in?(%{groups: groups}, group) when is_list(groups) do
    group in groups
  end
end
