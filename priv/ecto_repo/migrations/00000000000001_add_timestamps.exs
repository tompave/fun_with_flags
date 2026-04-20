defmodule FunWithFlags.Dev.EctoRepo.Migrations.CreateFeatureFlagsTable do
  use Ecto.Migration

  # This migration assumes the default table name of "fun_with_flags_toggles"
  # is being used. If you have overridden that via configuration, you should
  # change this migration accordingly.

  def change do
    alter table(:fun_with_flags_toggles) do
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :updated_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end
  end
end
