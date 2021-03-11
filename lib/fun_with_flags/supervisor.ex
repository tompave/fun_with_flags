defmodule FunWithFlags.Supervisor do
  @moduledoc """
  Implements `Supervisor.child_spec/1` to describe the supervision tree for the
  `:fun_with_flags` application.

  This module is used internally by the package when the application starts its
  own supervision tree (the default). If that is disabled, the host applcation
  should use this module to start the supervision tree directly.
  """

  alias FunWithFlags.Config
  require Logger

  # Automatically defines child_spec/1.
  use Supervisor


  # Requited because of the `child_spec/2` definition injected by `use Supervisor`.
  #
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end


  @impl true
  def init(_init_arg) do
    Supervisor.init(children(), strategy: :one_for_one)
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
    adapter = Config.persistence_adapter()

    try do
      adapter.worker_spec()
    rescue
      e in [UndefinedFunctionError] ->
        Logger.error "FunWithFlags: It looks like you're trying to use #{inspect(adapter)} " <>
         "to persist flags, but you haven't added its optional dependency to the Mixfile " <>
         "of your project."
        reraise e, __STACKTRACE__
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
        reraise e, __STACKTRACE__
    end
  end
end
