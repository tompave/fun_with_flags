if Code.ensure_loaded?(Ecto.Adapters.SQL) do

defmodule FunWithFlags.Store.Persistent.Ecto.Record do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias FunWithFlags.{Config, Gate}

  @primary_key {:id, Config.ecto_primary_key_type_determined_at_compile_time(), autogenerate: true}

  schema Config.ecto_table_name_determined_at_compile_time() do
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
    {type, target} = get_type_and_target(gate)

    data = %{
      flag_name: to_string(flag_name),
      gate_type: type,
      target: target,
      enabled: gate.enabled
    }
    changeset(%__MODULE__{}, data)
  end


  def update_target(record = %__MODULE__{gate_type: "percentage"}, gate) do
    {"percentage", target} = get_type_and_target(gate)
    change(record, target: target)
  end

  # Do not just store NULL for `target: nil`, because the unique
  # index in the table does not see NULL values as equal.
  #
  def serialize_target(nil), do: "_fwf_none"
  def serialize_target(str) when is_binary(str), do: str
  def serialize_target(atm) when is_atom(atm), do: to_string(atm)


  defp get_type_and_target(%Gate{type: :percentage_of_time, for: target}) do
    {"percentage", "time/#{to_string(target)}"}
  end

  defp get_type_and_target(%Gate{type: :percentage_of_actors, for: target}) do
    {"percentage", "actors/#{to_string(target)}"}
  end

  defp get_type_and_target(%Gate{type: type, for: target}) do
    {to_string(type), serialize_target(target)}
  end
end

end # Code.ensure_loaded?
