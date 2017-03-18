defprotocol FunWithFlags.Group do
  @moduledoc """
  Implement this protocol to provide groups.

  It comes with a fallback `Any` implementation, that defaults
  to always return `false`. In other words, unless this protocol
  is explicitly implemented nothing belongs to any group.
  """

  @fallback_to_any true

  @doc """
  Should return a boolean.

  The default implementation will always return `false` for
  any argument.

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


defimpl FunWithFlags.Group, for: Any do
  def in?(_, _), do: false
end
