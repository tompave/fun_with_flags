defmodule FunWithFlags.Application do
  @moduledoc false

  use Application
  alias FunWithFlags.Config

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children(), opts)
  end


  defp children do
    [
      FunWithFlags.Store.Persistent.adapter.worker_spec,
      cache_spec(),
      notifications_spec(),
    ]
    |> Enum.reject(&(!&1))
  end

  # Are the change notifications enabled AND can the notifications
  # adapter be supervised?
  #
  defp notifications_spec do
    Config.change_notifications_enabled? &&
      Config.notifications_adapter.worker_spec
  end


  defp cache_spec do
    import Supervisor.Spec, only: [worker: 3]

    if Config.cache? do
      worker(FunWithFlags.Store.Cache, [], restart: :permanent)
    end
  end
end
