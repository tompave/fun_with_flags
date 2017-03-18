defmodule FunWithFlags.Flag do
  @moduledoc false

  alias FunWithFlags.Gate

  defstruct [name: nil, gates: []]
  @type t :: %FunWithFlags.Flag{name: atom, gates: [FunWithFlags.Gate.t]}
  @type options :: Keyword.t


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


  @spec enabled?(t, options) :: boolean
  def enabled?(flag, options \\ [])

  def enabled?(%__MODULE__{gates: []}, _), do: false

  def enabled?(%__MODULE__{gates: gates}, []) do
    check_boolean_gate(gates)
  end


  def enabled?(%__MODULE__{gates: gates}, [for: item]) do
    case check_actor_gates(gates, item) do
      {:ok, bool} -> bool
      :ignore     -> check_boolean_gate(gates)
    end
  end


  defp check_actor_gates(gates, item) do
    gates
    |> actor_gates()
    |> do_check_actor_gates(item)
  end

  defp do_check_actor_gates([], _), do: :ignore

  defp do_check_actor_gates([gate|rest], item) do
    case Gate.enabled?(gate, for: item) do
      :ignore -> do_check_actor_gates(rest, item)
      result  -> result
    end
  end


  defp check_boolean_gate(gates) do
    gate = boolean_gate(gates)
    if gate do
      {:ok, bool} = Gate.enabled?(gate)
      bool
    else
      false
    end
  end


  defp boolean_gate(gates) do
    Enum.find(gates, &Gate.boolean?/1)
  end

  defp actor_gates(gates) do
    Enum.filter(gates, &Gate.actor?/1)
  end
end
