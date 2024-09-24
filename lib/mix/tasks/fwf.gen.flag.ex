defmodule Mix.Tasks.Fwf.Gen.Flag do
  @shortdoc "Generates a new migration for creating a feature flag"

  @moduledoc """
  Generates a flag migration.

  ## Examples

      $ mix fwf.gen.flag AwesomeFeature

  The generated migration filename will be prefixed with the current
  timestamp in UTC which is used for versioning and ordering.

  By default, the migration will be generated to the
  "priv/YOUR_REPO/migrations" directory of the current application
  but it can be configured to be any subdirectory of `priv` by
  specifying the `:priv` key under the repository configuration.

  ## Command line options

    * `--migrations-path` - the path to run the migrations from, defaults to `priv/repo/migrations`

  """

  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.EctoSQL
  import Mix.Generator

  @switches [
    migrations_path: :string
  ]

  @impl true
  def run(args) do
    repo = Application.fetch_env!(:fun_with_flags, :persistence)[:repo]

    unless FunWithFlags.Config.persist_in_ecto?() do
      Mix.raise("You need to configure FunWithFlags to persist in Ecto to use this task.")
    end

    case OptionParser.parse!(args, strict: @switches) do
      {opts, [name]} ->
        table_name = Application.fetch_env!(:fun_with_flags, :persistence)[:ecto_table_name]
        primary_key_type = Application.fetch_env!(:fun_with_flags, :persistence)[:ecto_primary_key_type]

        path = opts[:migrations_path] || Path.join(source_repo_priv(repo), "migrations")
        flag_name = underscore(name)
        base_name = "add_feature_flag_#{flag_name}.exs"
        file = Path.join(path, "#{timestamp()}_#{base_name}")
        unless File.dir?(path), do: create_directory(path)

        fuzzy_path = Path.join(path, "*_#{base_name}")

        if Path.wildcard(fuzzy_path) != [] do
          Mix.raise("migration can't be created, there is already a migration file with name #{name}.")
        end

        assigns = [
          mod: Module.concat([repo, Migrations, camelize(name)]),
          table_name: table_name,
          primary_key_type: primary_key_type,
          flag_name: flag_name
        ]

        create_file(file, migration_template(assigns))

        file

      {_, _} ->
        Mix.raise(
          "expected fwf.gen.flag to receive the migration file name, " <>
            "got: #{inspect(Enum.join(args, " "))}"
        )
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    use <%= inspect migration_module() %>

    require Ecto.Query

    defmodule FeatureFlagSchema do
      @moduledoc false
      use Ecto.Schema

      @primary_key {:id, <%= inspect @primary_key_type %>, autogenerate: true}

      schema <%= inspect @table_name %> do
        field(:flag_name, :string)
        field(:gate_type, :string)
        field(:target, :string)
        field(:enabled, :boolean)
      end
    end

    def up do
      repo().insert_all(FeatureFlagSchema, [
        %{
          flag_name: <%= inspect @flag_name %>,
          gate_type: "boolean",
          target: "_fwf_none",
          enabled: false
        }
      ])
    end

    def down do
      Ecto.Query.from(
        FeatureFlagSchema,
        where: [flag_name: <%= inspect @flag_name %>]
      )
      |> repo().delete_all()
    end
  end
  """)
end
