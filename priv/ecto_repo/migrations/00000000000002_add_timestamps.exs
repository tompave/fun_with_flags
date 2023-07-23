defmodule FunWithFlags.Dev.EctoRepo.Migrations.EnsureColumnsAreNotNull do
  use Ecto.Migration
  #
  # Use this migration to add the ecto `inserted_at` and `updated_at` columns
  # to the table created using the `CreateFeatureFlagsTable` migration
  # from versions `<= 1.10.0`.
  #
  # https://hexdocs.pm/ecto_sql/Ecto.Migration.html#timestamps/1
  #
  # If the table has been created with a migration from `>= 1.11.0`,
  # then the `timestamp` columns are already there and there
  # is no need to run this migration. In that case, this migration
  # is a no-op.
  #
  # This migration assumes the default table name of "fun_with_flags_toggles"
  # is being used. If you have overridden that via configuration, you should
  # change this migration accordingly.

  def up do
    case repo().query("select inserted_at, updated_at from fun_with_flags_toggles where false") do
      {:ok, %{num_rows: 0}} ->
        # timestamp columns exist, do nothing
        true

      {:error, _} ->
        # Assume error is from timestamp columns not existing, run migration
        alter table(:fun_with_flags_toggles) do
          timestamps()
        end
    end
  end

  def down do
    alter table(:fun_with_flags_toggles) do
      remove :inserted_at
      remove :updated_at
    end
  end
end
