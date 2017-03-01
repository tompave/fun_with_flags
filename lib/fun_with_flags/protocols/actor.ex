defprotocol FunWithFlags.Actor do
  @moduledoc """
  Implement this protocol to provide actors.
  """

  @doc """
  Should return a globally unique binary.
  """
  @spec id(term) :: binary
  def id(actor)
end
