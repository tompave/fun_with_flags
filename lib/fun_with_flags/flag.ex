defmodule FunWithFlags.Flag do
  defstruct [:name, :boolean, :actors, :groups]
  @type t :: %FunWithFlags.Flag{name: String.t, boolean: boolean}

  @spec enabled?(t) :: boolean
  def enabled?(flag) do
    flag.boolean
  end
end
