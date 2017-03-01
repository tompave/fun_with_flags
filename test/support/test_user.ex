defmodule FunWithFlags.TestUser do
  # A Test user
  defstruct [:id, :email]
end

defimpl FunWithFlags.Actor, for: FunWithFlags.TestUser do
  def id(user) do
    "user:#{user.id}"
  end
end
