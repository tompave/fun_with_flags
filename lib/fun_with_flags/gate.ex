defmodule FunWithFlags.Gate do
  @moduledoc false
  alias FunWithFlags.Actor
  
  defstruct [:type, :for, :enabled]
  @type t :: %FunWithFlags.Gate{type: atom, for: (nil | String.t), enabled: boolean}
  @type options :: Keyword.t

  def new(:boolean, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :boolean, for: nil, enabled: enabled}
  end

  def new(:actor, actor, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :actor, for: Actor.id(actor), enabled: enabled}
  end


  def from_redis(["boolean", enabled]) do
    %__MODULE__{type: :boolean, for: nil, enabled: parse_bool(enabled)}
  end

  def from_redis(["actor/" <> actor_id, enabled]) do
    %__MODULE__{type: :actor, for: actor_id, enabled: parse_bool(enabled)}
  end


  def boolean?(%__MODULE__{type: :boolean}), do: true
  def boolean?(%__MODULE__{type: _}),        do: false

  def actor?(%__MODULE__{type: :actor}), do: true
  def actor?(%__MODULE__{type: _}),      do: false



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


  def parse_bool("true"), do: true
  def parse_bool(_), do: false
end
