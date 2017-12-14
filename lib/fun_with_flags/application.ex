defmodule FunWithFlags.Application do
  @moduledoc false

  use Application
  alias FunWithFlags.Config
  require Logger

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    Supervisor.start_link(children(), opts)
  end


  defp children do
    [
      FunWithFlags.Config.persistence_adapter().worker_spec,
      cache_spec(),
      notifications_spec(),
    ]
    |> Enum.reject(&(!&1))
  end

  # If the change notifications are enabled AND the adapter can
  # be supervised, then return a spec for the supervisor.
  # Also handle cases where an adapter has been configured but its
  # optional dependency is not required in the Mixfile.
  #
  defp notifications_spec do
    try do
      Config.change_notifications_enabled? && Config.notifications_adapter.worker_spec
    rescue
      e in [UndefinedFunctionError] ->
        Logger.error "FunWithFlags: Looks like you're trying to use #{Config.notifications_adapter}, but you haven't added its optional dependency to the Mixfile."
        raise e
    end
  end


  defp cache_spec do
    import Supervisor.Spec, only: [worker: 3]

    if Config.cache? do
      worker(FunWithFlags.Store.Cache, [], restart: :permanent)
    end
  end
end
