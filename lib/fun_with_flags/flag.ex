defmodule FunWithFlags.Flag do
  @moduledoc """
  Represents a feature flag.

  This module is not meant to be used directly.
  """

  alias FunWithFlags.Gate

  defstruct [name: nil, gates: []]
  @type t :: %FunWithFlags.Flag{name: atom, gates: [FunWithFlags.Gate.t]}
  @typep options :: Keyword.t


  @doc false
  def new(name, gates \\ []) when is_atom(name) do
    %__MODULE__{name: name, gates: gates}
  end


  @doc false
  @spec enabled?(t, options) :: boolean
  def enabled?(flag, options \\ [])

  def enabled?(%__MODULE__{gates: []}, _), do: false

  # Check the boolean gate first, as if that's enabled we
  # can stop immediately. Also, a boolean gate is almost
  # always present, while a percentage_of_time gate is not
  # used often.
  #
  def enabled?(%__MODULE__{gates: gates}, []) do
    grouped_gates = collect_gates_by_type(gates)
    check_boolean_gate(grouped_gates[:boolean]) || check_percentage_of_time_gate(grouped_gates[:percentage_of_time])
  end


  def enabled?(%__MODULE__{gates: gates, name: flag_name}, [for: item]) do
    grouped_gates = collect_gates_by_type(gates)

    case check_actor_gates(grouped_gates[:actor], item) do
      {:ok, bool} -> bool
      :ignore ->
        case check_group_gates(grouped_gates[:group], item) do
          {:ok, bool} -> bool
          :ignore ->
            check_boolean_gate(grouped_gates[:boolean]) || check_percentage_gate(grouped_gates, item, flag_name)
        end
    end
  end


  defp check_percentage_gate(grouped_gates, item, flag_name) do
    case grouped_gates[:percentage_of_actors] do
      nil ->
        check_percentage_of_time_gate(grouped_gates[:percentage_of_time])
      [gate] ->
        check_percentage_of_actors_gate(gate, item, flag_name)
    end
  end


  defp check_actor_gates(gates, item) do
    gates
    |> do_check_actor_gates(item)
  end
  defp do_check_actor_gates([gate|rest], item) do
    case Gate.enabled?(gate, for: item) do
      :ignore -> do_check_actor_gates(rest, item)
      result  -> result
    end
  end
  defp do_check_actor_gates(_, _), do: :ignore


  defp check_group_gates(gates, item) do
    gates
    |> do_check_group_gates(item)
  end


  # If the tested item belongs to multiple conflicting groups,
  # the disabled ones take precedence. Guaranteeing that something
  # is consistently disabled is more important than the opposite.
  #
  # If a group gate is explicitly disabled, then return false.
  # If a group gate is enabled, store the result but keep
  # looping in case there is another group that is disabled.
  #
  defp do_check_group_gates(gates, item, result \\ :ignore)

  defp do_check_group_gates([gate|rest], item, temp_result) do
    case Gate.enabled?(gate, for: item) do
      :ignore      -> do_check_group_gates(rest, item, temp_result)
      {:ok, false} -> {:ok, false}
      {:ok, true}  -> do_check_group_gates(rest, item, {:ok, true})
    end
  end
  defp do_check_group_gates(_, _, result), do: result


  defp check_boolean_gate([gate = %Gate{type: :boolean}]) do
    {:ok, bool} = Gate.enabled?(gate)
    bool
  end
  defp check_boolean_gate(nil), do: false


  defp check_percentage_of_time_gate([gate = %Gate{type: :percentage_of_time}]) do
    {:ok, bool} = Gate.enabled?(gate)
    bool
  end
  defp check_percentage_of_time_gate(nil), do: false


  defp check_percentage_of_actors_gate(gate = %Gate{type: :percentage_of_actors}, item, flag_name) do
    {:ok, bool} = Gate.enabled?(gate, for: item, flag_name: flag_name)
    bool
  end

  defp collect_gates_by_type(gates) do
    Enum.group_by(gates, &(&1.type))
  end
end
