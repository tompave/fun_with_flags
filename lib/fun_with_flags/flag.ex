defmodule FunWithFlags.Flag do
  @moduledoc false

  defstruct [:name, :boolean, :actors, :groups]
  @type t :: %FunWithFlags.Flag{name: atom, boolean: boolean}

  # @gates ~w(boolean actors groups)a


  def new(name, bool) when is_binary(name) do
    new(String.to_atom(name), bool)
  end
  def new(name, bool) do
    %__MODULE__{name: name, boolean: bool}
  end


  @spec enabled?(t) :: boolean
  def enabled?(flag) do
    flag.boolean
  end


  def to_redis(flag = %__MODULE__{}) do
    {flag.name, ["boolean", flag.boolean]}
  end


  # defp is_gate?(name) do
  #   name in @gates
  # end
end
