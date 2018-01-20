defmodule FunWithFlags.TestCase do
  use ExUnit.CaseTemplate
  alias FunWithFlags.Dev.EctoRepo, as: Repo

  setup tags do
    # Setup the SQL sandbox if the persistent store is Ecto
    if FunWithFlags.Config.persist_in_ecto?() do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
      end
    end

    :ok
  end
end
