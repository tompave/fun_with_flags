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
      FunWithFlags.Store.Cache.worker_spec(),
      persistence_spec(),
      notifications_spec(),
    ]
    |> Enum.reject(&(!&1))
  end


  defp persistence_spec do
    adapter = FunWithFlags.Store.Persistent.adapter()

    try do
      adapter.worker_spec()
    rescue
      e in [UndefinedFunctionError] ->
        Logger.error "FunWithFlags: It looks like you're trying to use #{inspect(adapter)} " <>
         "to persist flags, but you haven't added its optional dependency to the Mixfile " <>
         "of your project."
        reraise e, System.stacktrace
    end
  end

  # If the change notifications are enabled AND the adapter can
  # be supervised, then return a spec for the supervisor.
  # Also handle cases where an adapter has been configured but its
  # optional dependency is not required in the Mixfile.
  #
  defp notifications_spec do
    try do
      Config.change_notifications_enabled? && Config.notifications_adapter.worker_spec()
    rescue
      e in [UndefinedFunctionError] ->
        Logger.error "FunWithFlags: It looks like you're trying to use #{inspect(Config.notifications_adapter)} " <>
         "for the cache-busting notifications, but you haven't added its optional dependency to the Mixfile " <>
         "of your project. If you don't need cache-busting notifications, they can be disabled to make this " <>
         "error go away."
        reraise e, System.stacktrace
    end
  end
end
