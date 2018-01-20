defmodule FunWithFlags.Store.Persistent do
  @moduledoc false

  @adapter FunWithFlags.Config.persistence_adapter()

  def adapter, do: @adapter
end
