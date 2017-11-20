defmodule FunWithFlags.Gate do
  @moduledoc false
  alias FunWithFlags.{Actor, Group}
  
  defstruct [:type, :for, :enabled]
  @type t :: %FunWithFlags.Gate{type: atom, for: (nil | String.t), enabled: boolean}
  @type options :: Keyword.t

  def new(:boolean, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :boolean, for: nil, enabled: enabled}
  end

  def new(:actor, actor, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :actor, for: Actor.id(actor), enabled: enabled}
  end

  def new(:group, group_name, enabled) when is_boolean(enabled) do
    validate_group_name(group_name)
    %__MODULE__{type: :group, for: to_string(group_name), enabled: enabled}
  end

  # Don't accept 0 or 1 because a boolean gate should be used instead.
  #
  def new(:percent_of_time, ratio)
  when is_float(ratio) and ratio > 0 and ratio < 1 do
    %__MODULE__{type: :percent_of_time, for: ratio, enabled: true}
  end

  defmodule InvalidGroupNameError do
    defexception [:message]
  end

  defp validate_group_name(name) when is_binary(name) or is_atom(name), do: nil
  defp validate_group_name(name) do
    raise InvalidGroupNameError, "invalid group name '#{inspect(name)}', it should be a binary or an atom."
  end


  def boolean?(%__MODULE__{type: :boolean}), do: true
  def boolean?(%__MODULE__{type: _}),        do: false

  def actor?(%__MODULE__{type: :actor}), do: true
  def actor?(%__MODULE__{type: _}),      do: false

  def group?(%__MODULE__{type: :group}), do: true
  def group?(%__MODULE__{type: _}),      do: false

  def percent_of_time?(%__MODULE__{type: :percent_of_time}), do: true
  def percent_of_time?(%__MODULE__{type: _}),                do: false



  @spec enabled?(t, options) :: boolean
  def enabled?(gate, options \\ [])

  def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, []) do
    {:ok, enabled}
  end
  def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, [for: _]) do
    {:ok, enabled}
  end

  def enabled?(%__MODULE__{type: :actor, for: actor_id, enabled: enabled}, [for: actor]) do
    case Actor.id(actor) do
      ^actor_id -> {:ok, enabled}
      _         -> :ignore
    end
  end

  def enabled?(%__MODULE__{type: :group, for: group, enabled: enabled}, [for: item]) do
    if Group.in?(item, group) do
      {:ok, enabled}
    else
      :ignore
    end
  end

  def enabled?(%__MODULE__{type: :percent_of_time, for: ratio}, _) do
    roll = random_float
    enabled = roll <= ratio
    {:ok, enabled}
  end

  # Returns a float (2 digit precision) between 0.0 and 1.0
  #
  defp random_float do
    (:rand.uniform(100) / 100)
  end
end
