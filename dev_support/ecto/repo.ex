if FunWithFlags.Config.persist_in_ecto? do
  defmodule FunWithFlags.Dev.EctoRepo do
    use Ecto.Repo, otp_app: :fun_with_flags, adapter: Ecto.Adapters.Postgres
  end
end
