if FunWithFlags.Config.persist_in_ecto? do
  defmodule FunWithFlags.Dev.EctoRepo do

    # Only for dev and test.
    #
    @variant (case System.get_env("RDBMS") do
      "mysql" ->
        # Ecto.Adapters.MySQL # mariaex, legacy
        Ecto.Adapters.MyXQL # myxql, introduced in ecto_sql 3.1
      "sqlite" ->
        Ecto.Adapters.SQLite3
      _ ->
        Ecto.Adapters.Postgres
    end)

    use Ecto.Repo, otp_app: :fun_with_flags, adapter: @variant

    # For testing setups that use multi-tenancy using foreign keys
    # as described in the Ecto docs:
    # https://hexdocs.pm/ecto/3.8.4/multi-tenancy-with-foreign-keys.html
    #
    # FunWithFlags sets the custom query option `:fun_with_flags` to
    # `true` to allow such setups to detect queries originating from
    # FunWithFlags.
    #
    # This dev/repo implements the callback simplu as a detection mechanism:
    # if the package code changed to remove the custom query option, this will
    # cause the tests to fail. Other than that, it has no purpose.
    #
    @impl true
    def prepare_query(_operation, query, opts) do
      cond do
        opts[:schema_migration] || opts[:fun_with_flags] ->
          {query, opts}

        true ->
          raise "expected fun_with_flags query option to be set"
      end
    end
  end
end
