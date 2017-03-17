defmodule FunWithFlags.TestUser do
  # A Test user
  defstruct [:id, :email]
end

defimpl FunWithFlags.Actor, for: FunWithFlags.TestUser do
  def id(user) do
    "user:#{user.id}"
  end
end


defimpl FunWithFlags.Group, for: FunWithFlags.TestUser do
  def in?(%{email: email}, :admin) do
    String.contains?(email, "@wayne.com")
  end
  def in?(_, _), do: false
end
