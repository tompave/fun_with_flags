defmodule FunWithFlags.Store.Persistent do
  @adapter FunWithFlags.Config.persistence_adapter

  def adapter, do: @adapter
end
