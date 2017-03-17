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
    %__MODULE__{type: :group, for: group_name, enabled: enabled}
  end

  defmodule InvalidGroupNameError do
    defexception [:message]
  end

  defp validate_group_name(name) when is_atom(name), do: nil
  defp validate_group_name(name) do
    raise InvalidGroupNameError, "invalid group name '#{inspect(name)}', it should be an atom."
  end


  def from_redis(["boolean", enabled]) do
    %__MODULE__{type: :boolean, for: nil, enabled: parse_bool(enabled)}
  end

  def from_redis(["actor/" <> actor_id, enabled]) do
    %__MODULE__{type: :actor, for: actor_id, enabled: parse_bool(enabled)}
  end

  def from_redis(["group/" <> group_name, enabled]) do
    %__MODULE__{type: :group, for: String.to_atom(group_name), enabled: parse_bool(enabled)}
  end


  def boolean?(%__MODULE__{type: :boolean}), do: true
  def boolean?(%__MODULE__{type: _}),        do: false

  def actor?(%__MODULE__{type: :actor}), do: true
  def actor?(%__MODULE__{type: _}),      do: false

  def group?(%__MODULE__{type: :group}), do: true
  def group?(%__MODULE__{type: _}),      do: false



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


  def parse_bool("true"), do: true
  def parse_bool(_), do: false
end
