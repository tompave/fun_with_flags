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
    |> unique_constraint(
      :gate_type,
      name: "fwf_flag_name_gate_target_idx",
      message: "Can't store a duplicated gate."
    )
  end


  def build(flag_name, gate) do
    data = %{
      flag_name: to_string(flag_name),
      gate_type: to_string(gate.type),
      target: to_string(gate.for),
      enabled: gate.enabled
    }
    changeset(%__MODULE__{}, data)
  end
end
