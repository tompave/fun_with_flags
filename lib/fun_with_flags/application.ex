defmodule FunWithFlags.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children(), opts)
  end


  defp children do
    import Supervisor.Spec, warn: false

    if FunWithFlags.Config.cache? do
      [
        supervisor(FunWithFlags.Store.Supervisor, [], restart: :permanent),
        worker(FunWithFlags.Notifications, [], restart: :permanent),
      ]
    else
      [
        supervisor(FunWithFlags.Store.Supervisor, [], restart: :permanent),
      ]
    end
  end
end
