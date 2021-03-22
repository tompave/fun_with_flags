defmodule FunWithFlags.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    FunWithFlags.Supervisor.start_link(nil)
  end
end
