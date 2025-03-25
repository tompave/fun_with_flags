defmodule FunWithFlags.Dev.EctoRepo.Migrations.AddTimestamps do
  use Ecto.Migration

  def up do
    alter table(:fun_with_flags_toggles) do
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :updated_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end
  end

  def down do
    alter table(:fun_with_flags_toggles) do
      remove :inserted_at
      remove :updated_at
    end
  end
end
