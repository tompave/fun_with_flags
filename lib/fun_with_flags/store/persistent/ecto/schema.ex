defmodule FunWithFlags.Store.Persistent.Ecto.Schema do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fun_with_flags_toggles" do
    field :flag_name, :string
    field :gate_type, :string
    field :target, :string
    field :enabled, :boolean
  end

  @fields [:flag_name, :gate_type, :target, :enabled]
  @required_fields [:flag_name, :gate_type, :enabled]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
