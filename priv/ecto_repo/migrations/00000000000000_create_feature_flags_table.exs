defmodule FunWithFlags.Dev.EctoRepo.Migrations.CreateFeatureFlagsTable do
  use Ecto.Migration

  def up do
    create table(:fun_with_flags_toggles) do
      add :flag_name, :string
      add :gate_type, :string
      add :target, :string
      add :enabled, :boolean
    end

    create index(
      :fun_with_flags_toggles,
      [:flag_name, :gate_type, :target],
      [unique: true, name: "fwf_flag_name_gate_target_idx"]
    )
  end

  def down do
    drop table(:fun_with_flags_toggles)
  end
end
