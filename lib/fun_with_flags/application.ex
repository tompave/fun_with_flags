defmodule FunWithFlags.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children(), opts)
  end


  defp children do
    import Supervisor.Spec, warn: false

    if with_cache_bust_notifications?() do
      [
        supervisor(FunWithFlags.Store.Supervisor, [], restart: :permanent),
        worker(FunWithFlags.Config.notifications_adapter(), [], restart: :permanent),
      ]
    else
      [
        supervisor(FunWithFlags.Store.Supervisor, [], restart: :permanent),
      ]
    end
  end


  defp with_cache_bust_notifications? do
    FunWithFlags.Config.cache? &&
      FunWithFlags.Config.change_notifications_supported?
  end
end
