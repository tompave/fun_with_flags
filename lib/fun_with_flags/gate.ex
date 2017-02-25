defmodule FunWithFlags.Gate do
  @moduledoc false
  
  defstruct [:type, :for, :enabled]
  @type t :: %FunWithFlags.Gate{type: atom, for: (nil | String.t), enabled: boolean}


  def new(:boolean, enabled) when is_boolean(enabled) do
    %__MODULE__{type: :boolean, for: nil, enabled: enabled}
  end

  def from_redis(["boolean", enabled]) do
    new(:boolean, parse_bool(enabled))
  end


  def boolean?(%__MODULE__{type: :boolean}), do: true
  def boolean?(%__MODULE__{type: _}),        do: false


  def enabled?(%{type: :boolean, enabled: enabled}) do
    enabled
  end
  # def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, [for: _]) do
  #   enabled
  # end


  def parse_bool("true"), do: true
  def parse_bool(_), do: false
end
