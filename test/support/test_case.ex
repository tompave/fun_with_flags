defmodule FunWithFlags.TestCase do
  use ExUnit.CaseTemplate

  setup do
    # Setup the SQL sandbox if the persistent store is Ecto
    if FunWithFlags.Config.persistence_adapter() == FunWithFlags.Store.Persistent.Ecto do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(FunWithFlags.Dev.EctoRepo)
    end
  end
end
