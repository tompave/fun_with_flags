defmodule FunWithFlags.NullEctoRepo do
  @moduledoc false

  # This is here just to raise some more helpful errors if a user
  # forgets to configure an Ecto repo.

  @error_msg "The NullEctoRepo doesn't implement this. You must configure a proper repo to persist flags with Ecto."

  def all(_), do: raise(@error_msg)
  def insert(_, _), do: raise(@error_msg)
  def delete_all(_), do: raise(@error_msg)
end
