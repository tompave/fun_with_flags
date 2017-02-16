defmodule FunWithFlags.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(FunWithFlags.Store.Supervisor, [], restart: :permanent),
      worker(FunWithFlags.Notifications, [], restart: :permanent),
    ]

    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
