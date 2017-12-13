defmodule FunWithFlags.Store.Persistent do
  @moduledoc false

  def adapter, do: FunWithFlags.Config.persistence_adapter
end
