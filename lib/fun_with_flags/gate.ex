defmodule FunWithFlags.Gate do
  @moduledoc false
  
  defstruct [:type, :for, :enabled]
  @type t :: %FunWithFlags.Gate{type: atom, for: (nil | String.t), enabled: boolean}


  def new(:boolean, enabled) do
    %__MODULE__{type: :boolean, for: nil, enabled: !!enabled}
  end


  def enabled?(%{type: :boolean, enabled: enabled}) do
    enabled
  end
  # def enabled?(%__MODULE__{type: :boolean, enabled: enabled}, [for: _]) do
  #   enabled
  # end
end
