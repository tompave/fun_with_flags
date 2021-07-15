defmodule FunWithFlags.Flag do
  @moduledoc """
  Represents a feature flag.

  This module is not meant to be used directly.
  """

  alias FunWithFlags.Gate

  defstruct name: nil, gates: []
  @type t :: %FunWithFlags.Flag{name: atom, gates: [FunWithFlags.Gate.t()]}
  @typep options :: Keyword.t()

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
    check_boolean_gate(gates) || check_percentage_of_time_gate(gates)
  end

  def enabled?(%__MODULE__{gates: gates, name: flag_name}, for: item) do
    case check_actor_gates(gates, item) do
      {:ok, bool} ->
        bool

      :ignore ->
        case check_group_gates(gates, item) do
          {:ok, bool} ->
            bool

          :ignore ->
            check_boolean_gate(gates) || check_percentage_gate(gates, item, flag_name)
        end
    end
  end

  defp check_percentage_gate(gates, item, flag_name) do
    case percentage_of_actors_gate(gates) do
      nil ->
        check_percentage_of_time_gate(gates)

      gate ->
        check_percentage_of_actors_gate(gate, item, flag_name)
    end
  end

  defp check_actor_gates(gates, item) do
    gates
    |> actor_gates()
    |> do_check_actor_gates(item)
  end

  defp do_check_actor_gates([], _), do: :ignore

  defp do_check_actor_gates([gate | rest], item) do
    case Gate.enabled?(gate, for: item) do
      :ignore -> do_check_actor_gates(rest, item)
      result -> result
    end
  end

  defp check_group_gates(gates, item) do
    gates
    |> group_gates()
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

  defp do_check_group_gates([], _, result), do: result

  defp do_check_group_gates([gate | rest], item, temp_result) do
    case Gate.enabled?(gate, for: item) do
      :ignore -> do_check_group_gates(rest, item, temp_result)
      {:ok, false} -> {:ok, false}
      {:ok, true} -> do_check_group_gates(rest, item, {:ok, true})
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

  defp check_percentage_of_time_gate(gates) do
    gate = percentage_of_time_gate(gates)

    if gate do
      {:ok, bool} = Gate.enabled?(gate)
      bool
    else
      false
    end
  end

  defp check_percentage_of_actors_gate(gate, item, flag_name) do
    {:ok, bool} = Gate.enabled?(gate, for: item, flag_name: flag_name)
    bool
  end

  defp boolean_gate(gates) do
    Enum.find(gates, &Gate.boolean?/1)
  end

  defp actor_gates(gates) do
    Enum.filter(gates, &Gate.actor?/1)
  end

  defp group_gates(gates) do
    Enum.filter(gates, &Gate.group?/1)
  end

  defp percentage_of_time_gate(gates) do
    Enum.find(gates, &Gate.percentage_of_time?/1)
  end

  defp percentage_of_actors_gate(gates) do
    Enum.find(gates, &Gate.percentage_of_actors?/1)
  end
end
