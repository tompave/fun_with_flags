defmodule FunWithFlags.Dev.EctoRepo.Migrations.CreateFeatureFlagsTable do
  use Ecto.Migration

  def up do
    create table(:fun_with_flags_toggles, primary_key: false) do
      add :flag_name, :string, primary_key: true
      add :gate_type, :string, primary_key: true
      add :target, :string, primary_key: true
      add :enabled, :boolean
    end
  end

  def down do
    drop table(:fun_with_flags_toggles)
  end
end
