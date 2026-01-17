if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.FunWithFlags.Install do
    @shortdoc "Installs and configures FunWithFlags"

    @moduledoc """
    Installs and configures FunWithFlags for your application.

    ## Usage

        mix fun_with_flags.install [options]

    ## Options

      * `--persistence` - The persistence adapter to use. Options: `ecto`, `redis`. Defaults to `ecto`.
      * `--pubsub` - The pubsub adapter to use. Options: `phoenix`, `redis`. Defaults to `phoenix`.
      * `--repo` - The Ecto repo to use (required when persistence is `ecto`).
      * `--table-name` - The Ecto table name. Defaults to `fun_with_flags_toggles`.

    ## Examples

        # Install with Ecto persistence and Phoenix PubSub
        mix fun_with_flags.install --persistence ecto --repo MyApp.Repo

        # Install with Redis persistence and Redis PubSub
        mix fun_with_flags.install --persistence redis --pubsub redis

    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :fun_with_flags,
        adds_deps: [],
        installs: [],
        example: "mix fun_with_flags.install --persistence ecto --repo MyApp.Repo",
        only: nil,
        positional: [],
        schema: [
          persistence: :string,
          pubsub: :string,
          repo: :string,
          table_name: :string
        ],
        defaults: [
          persistence: "ecto",
          pubsub: "phoenix",
          table_name: "fun_with_flags_toggles"
        ],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      opts = igniter.args.options

      persistence = opts[:persistence]
      pubsub = opts[:pubsub]
      repo = opts[:repo]
      table_name = opts[:table_name]

      validate_and_configure(igniter, persistence, pubsub, repo, table_name)
    end

    defp validate_and_configure(igniter, persistence, pubsub, repo, table_name) do
      case {persistence, repo} do
        {"ecto", nil} ->
          select_repo_and_configure(igniter, pubsub, table_name)

        {"ecto", repo_string} ->
          repo_module = Module.concat([repo_string])
          configure_with_ecto(igniter, repo_module, pubsub, table_name)

        {"redis", _} ->
          configure_with_redis(igniter, pubsub)

        {invalid, _} ->
          Igniter.add_issue(
            igniter,
            "Invalid persistence adapter: #{inspect(invalid)}. Must be 'ecto' or 'redis'."
          )
      end
    end

    defp select_repo_and_configure(igniter, pubsub, table_name) do
      case Igniter.Libs.Ecto.select_repo(igniter, label: "Which Ecto repo should FunWithFlags use?") do
        {igniter, nil} ->
          Igniter.add_issue(
            igniter,
            "No Ecto repo found. Please specify a repo with --repo or ensure your project has an Ecto repo configured."
          )

        {igniter, repo} ->
          configure_with_ecto(igniter, repo, pubsub, table_name)
      end
    end

    defp configure_with_ecto(igniter, repo, pubsub, table_name) do
      persistence_config =
        {:code,
         Sourceror.parse_string!("""
         [adapter: FunWithFlags.Store.Persistent.Ecto, repo: #{inspect(repo)}]
         """)}

      igniter
      |> configure_persistence(persistence_config)
      |> configure_cache()
      |> configure_pubsub(pubsub)
      |> generate_ecto_migration(repo, table_name)
      |> add_ecto_notices(repo, table_name)
    end

    defp configure_with_redis(igniter, pubsub) do
      persistence_config =
        {:code,
         Sourceror.parse_string!("""
         [adapter: FunWithFlags.Store.Persistent.Redis]
         """)}

      igniter
      |> configure_persistence(persistence_config)
      |> configure_redis()
      |> configure_cache()
      |> configure_pubsub(pubsub)
      |> add_redis_notices()
    end

    defp configure_persistence(igniter, persistence_config) do
      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :fun_with_flags,
        [:persistence],
        persistence_config
      )
    end

    defp configure_redis(igniter) do
      redis_config =
        {:code,
         Sourceror.parse_string!("""
         [host: "localhost", port: 6379, database: 0]
         """)}

      Igniter.Project.Config.configure_new(
        igniter,
        "config.exs",
        :fun_with_flags,
        [:redis],
        redis_config
      )
    end

    defp configure_cache(igniter) do
      cache_config =
        {:code,
         Sourceror.parse_string!("""
         [enabled: true, ttl: 900]
         """)}

      Igniter.Project.Config.configure_new(
        igniter,
        "config.exs",
        :fun_with_flags,
        [:cache],
        cache_config
      )
    end

    defp configure_pubsub(igniter, "phoenix") do
      pubsub_config =
        {:code,
         Sourceror.parse_string!("""
         [adapter: FunWithFlags.Notifications.PhoenixPubSub, client: nil]
         """)}

      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        :fun_with_flags,
        [:cache_bust_notifications],
        pubsub_config
      )
      |> Igniter.add_notice("""
      FunWithFlags is configured to use Phoenix.PubSub for cache notifications.

      You need to set the :client option in your config to your PubSub module:

          config :fun_with_flags, :cache_bust_notifications,
            adapter: FunWithFlags.Notifications.PhoenixPubSub,
            client: MyApp.PubSub
      """)
    end

    defp configure_pubsub(igniter, "redis") do
      pubsub_config =
        {:code,
         Sourceror.parse_string!("""
         [adapter: FunWithFlags.Notifications.Redis]
         """)}

      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :fun_with_flags,
        [:cache_bust_notifications],
        pubsub_config
      )
    end

    defp configure_pubsub(igniter, invalid) do
      Igniter.add_issue(
        igniter,
        "Invalid pubsub adapter: #{inspect(invalid)}. Must be 'phoenix' or 'redis'."
      )
    end

    defp generate_ecto_migration(igniter, repo, table_name) do
      migration_body = """
        def change do
          create table(:#{table_name}) do
            add :flag_name, :string, null: false
            add :gate_type, :string, null: false
            add :target, :string, null: false
            add :enabled, :boolean, null: false
          end

          create index(:#{table_name}, [:flag_name])
          create unique_index(:#{table_name}, [:flag_name, :gate_type, :target], name: "fwf_flag_name_gate_target_idx")
        end
      """

      Igniter.Libs.Ecto.gen_migration(
        igniter,
        repo,
        "create_fun_with_flags_table",
        body: migration_body,
        on_exists: :skip
      )
    end

    defp add_ecto_notices(igniter, repo, table_name) do
      Igniter.add_notice(igniter, """
      FunWithFlags has been configured with Ecto persistence.

      Summary:
        - Persistence: Ecto (#{inspect(repo)})
        - Table name: #{table_name}

      Next steps:
        1. Run `mix deps.get` to fetch dependencies
        2. Run `mix ecto.migrate` to create the flags table
        3. Start using FunWithFlags in your application!

      Basic usage:
        FunWithFlags.enabled?(:my_feature)
        FunWithFlags.enable(:my_feature)
        FunWithFlags.disable(:my_feature)
      """)
    end

    defp add_redis_notices(igniter) do
      Igniter.add_notice(igniter, """
      FunWithFlags has been configured with Redis persistence.

      Summary:
        - Persistence: Redis
        - Default Redis config: localhost:6379, database 0

      Next steps:
        1. Run `mix deps.get` to fetch dependencies
        2. Ensure you have `{:redix, "~> 1.0"}` in your dependencies
        3. Configure your Redis connection if needed:

            config :fun_with_flags, :redis,
              host: "localhost",
              port: 6379,
              database: 0

        4. Start using FunWithFlags in your application!

      Basic usage:
        FunWithFlags.enabled?(:my_feature)
        FunWithFlags.enable(:my_feature)
        FunWithFlags.disable(:my_feature)
      """)
    end
  end
end
