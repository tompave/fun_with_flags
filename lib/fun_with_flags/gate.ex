defmodule FunWithFlags.Gate do
  @moduledoc """
  Represents a feature flag gate, that is one of several conditions
  attached to a feature flag.

  This module is not meant to be used directly.
  """

  alias FunWithFlags.{Actor, Group}

  defmodule InvalidGroupNameError do
    defexception [:message]
  end

  defmodule InvalidTargetError do
    defexception [:message]
  end

  defstruct [:type, :for, :enabled]
  @type t :: %FunWithFlags.Gate{type: atom, for: nil | String.t(), enabled: boolean}
  @typep options :: Keyword.t()

  @doc false
  @spec new(atom, boolean | float) :: t
  def new(:boolean, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :boolean, for: nil, enabled: enabled}
  end

  # Don't accept 0 or 1 because a boolean gate should be used instead.
  #
  def new(:percentage_of_time, ratio)
      when is_float(ratio) and ratio > 0 and ratio < 1 do
    %__MODULE__{type: :percentage_of_time, for: ratio, enabled: true}
  end

  def new(:percentage_of_time, ratio)
      when (is_float(ratio) and ratio <= 0) or ratio >= 1 do
    raise InvalidTargetError,
          "percentage_of_time gates must have a ratio in the range '0.0 < r < 1.0'."
  end

  def new(:percentage_of_actors, ratio)
      when is_float(ratio) and ratio > 0 and ratio < 1 do
    %__MODULE__{type: :percentage_of_actors, for: ratio, enabled: true}
  end

  def new(:percentage_of_actors, ratio)
      when (is_float(ratio) and ratio <= 0) or ratio >= 1 do
    raise InvalidTargetError,
          "percentage_of_actors gates must have a ratio in the range '0.0 < r < 1.0'."
  end

  @doc false
  @spec new(atom, binary | term, boolean) :: t
  def new(:actor, actor, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :actor, for: Actor.id(actor), enabled: enabled}
  end

  def new(:group, group_name, enabled) when is_boolean(enabled) do
    validate_group_name(group_name)
    %__MODULE__{type: :group, for: to_string(group_name), enabled: enabled}
  end

  defp validate_group_name(name) when is_binary(name) or is_atom(name), do: nil

  defp validate_group_name(name) do
    raise InvalidGroupNameError,
          "invalid group name '#{inspect(name)}', it should be a binary or an atom."
  end

  @doc false
  def boolean?(%__MODULE__{type: :boolean}), do: true
  def boolean?(%__MODULE__{type: _}), do: false

  @doc false
  def actor?(%__MODULE__{type: :actor}), do: true
  def actor?(%__MODULE__{type: _}), do: false

  @doc false
  def group?(%__MODULE__{type: :group}), do: true
  def group?(%__MODULE__{type: _}), do: false

  @doc false
  def percentage_of_time?(%__MODULE__{type: :percentage_of_time}), do: true
  def percentage_of_time?(%__MODULE__{type: _}), do: false

  @doc false
  def percentage_of_actors?(%__MODULE__{type: :percentage_of_actors}), do: true
  def percentage_of_actors?(%__MODULE__{type: _}), do: false

  @doc false
  @spec enabled?(t, options) :: {:ok, boolean} | :ignore
  def enabled?(gate, options \\ [])

  def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, []) do
    {:ok, enabled}
  end

  def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, for: _) do
    {:ok, enabled}
  end

  def enabled?(%__MODULE__{type: :actor, for: actor_id, enabled: enabled}, for: actor) do
    case Actor.id(actor) do
      ^actor_id -> {:ok, enabled}
      _ -> :ignore
    end
  end

  def enabled?(%__MODULE__{type: :group, for: group, enabled: enabled}, for: item) do
    if Group.in?(item, group) do
      {:ok, enabled}
    else
      :ignore
    end
  end

  def enabled?(%__MODULE__{type: :percentage_of_time, for: ratio}, _) do
    roll = random_float()
    enabled = roll <= ratio
    {:ok, enabled}
  end

  def enabled?(%__MODULE__{type: :percentage_of_actors, for: ratio}, opts) do
    actor = Keyword.fetch!(opts, :for)
    flag_name = Keyword.fetch!(opts, :flag_name)

    roll = Actor.Percentage.score(actor, flag_name)
    enabled = roll <= ratio
    {:ok, enabled}
  end

  # Returns a float (4 digit precision) between 0.0 and 1.0
  #
  # Alternative:
  # :crypto.rand_uniform(1, 10_000) / 10_000
  #
  defp random_float do
    :rand.uniform(10_000) / 10_000
  end
end
