defmodule FunWithFlags.Flag do
  @moduledoc false

  alias FunWithFlags.Gate

  defstruct [name: nil, gates: []]
  @type t :: %FunWithFlags.Flag{name: atom, gates: [FunWithFlags.Gate.t]}


  def new(name) when is_binary(name) do
    new(String.to_atom(name))
  end
  def new(name) do
    %__MODULE__{name: name}
  end


  @spec enabled?(t) :: boolean
  def enabled?(%__MODULE__{gates: []}), do: false
  def enabled?(%__MODULE__{gates: gates}) do
    gates
    |> boolean_gate()
    |> Gate.enabled?()
  end


  defp boolean_gate(gates) do
    Enum.find(gates, &Gate.boolean?/1)
  end
end
