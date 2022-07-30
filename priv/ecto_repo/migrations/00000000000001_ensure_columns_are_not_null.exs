defmodule FunWithFlags.Dev.EctoRepo.Migrations.EnsureColumnsAreNotNull do
  use Ecto.Migration
  #
  # Use this migration to add the `not null` constraints to the
  # table created using the `CreateFeatureFlagsTable` migration
  # from versions `<= 1.0.0`.
  #
  # If the table has been created with a migration from `>= 1.1.0`,
  # then the `not null` constraints are already there and there
  # is no need to run this migration. In that case, this migration
  # is a no-op.
  #
  # This migration assumes the default table name of "fun_with_flags_toggles"
  # is being used. If you have overridden that via configuration, you should
  # change this migration accordingly.

  def up do
    alter table(:fun_with_flags_toggles) do
      modify :flag_name, :string, null: false
      modify :gate_type, :string, null: false
      modify :target, :string, null: false
      modify :enabled, :boolean, null: false
    end
  end

  def down do
    alter table(:fun_with_flags_toggles) do
      modify :flag_name, :string, null: true
      modify :gate_type, :string, null: true
      modify :target, :string, null: true
      modify :enabled, :boolean, null: true
    end
  end
end
