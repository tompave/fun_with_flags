defmodule FunWithFlags.TestCase do
  use ExUnit.CaseTemplate

  setup do
    # Setup the SQL sandbox if the persistent store is Ecto
    if FunWithFlags.Config.persist_in_ecto? do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(FunWithFlags.Dev.EctoRepo)
    end
  end
end
