if FunWithFlags.Config.persist_in_ecto?() do
  defmodule FunWithFlags.Dev.EctoRepo do
    # Only for dev and test.
    #
    @variant (case System.get_env("RDBMS") do
                "mysql" ->
                  # Ecto.Adapters.MySQL # mariaex, legacy
                  # myxql, introduced in ecto_sql 3.1
                  Ecto.Adapters.MyXQL

                _ ->
                  Ecto.Adapters.Postgres
              end)

    use Ecto.Repo, otp_app: :fun_with_flags, adapter: @variant
  end
end
