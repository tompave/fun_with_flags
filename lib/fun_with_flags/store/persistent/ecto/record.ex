if Code.ensure_loaded?(Ecto) do

defmodule FunWithFlags.Store.Persistent.Ecto.Record do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "fun_with_flags_toggles" do
    field :flag_name, :string
    field :gate_type, :string
    field :target, :string
    field :enabled, :boolean
  end

  @fields [:flag_name, :gate_type, :target, :enabled]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
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
      target: serialize_target(gate.for),
      enabled: gate.enabled
    }
    changeset(%__MODULE__{}, data)
  end

  # Do not just store NULL for `target: nil`, because the unique
  # index in the table does not see NULL values as equal.
  # 
  def serialize_target(nil), do: "_fwf_none"
  def serialize_target(str) when is_binary(str), do: str
  def serialize_target(atm) when is_atom(atm), do: to_string(atm)
  def serialize_target(flo) when is_float(flo), do: to_string(flo)
end

end # Code.ensure_loaded?
