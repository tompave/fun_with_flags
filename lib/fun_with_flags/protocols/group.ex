defprotocol FunWithFlags.Group do
  @moduledoc """
  Implement this protocol to provide groups.
  """

  @doc """
  Should return a boolean


  ## Example

      iex> user = %{name: "bolo", group: :staff}
      iex> FunWithFlags.Group.in?(data, :staff)
      true
      iex> FunWithFlags.Group.in?(data, :superusers)
      false
  """
  @spec in?(term, atom) :: boolean
  def in?(item, group)
end
