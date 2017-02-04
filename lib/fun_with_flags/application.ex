defmodule FunWithFlags.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(FunWithFlags.Store.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
