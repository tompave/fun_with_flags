defmodule FunWithFlags.Flag do
  @moduledoc false

  alias FunWithFlags.Gate

  defstruct [name: nil, gates: []]
  @type t :: %FunWithFlags.Flag{name: atom, gates: [FunWithFlags.Gate.t]}


  def new(name, gates \\ []) when is_atom(name) do
    %__MODULE__{name: name, gates: gates}
  end


  def from_redis(name, []), do: new(name, [])
  def from_redis(name, list) when is_list(list) do
    gates =
      list
      |> Enum.chunk(2)
      |> Enum.map(&Gate.from_redis/1)
    new(name, gates)
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
