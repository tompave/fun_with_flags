defmodule FunWithFlags.Store.Supervisor do
  @moduledoc false

  use Supervisor
  alias FunWithFlags.Config

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    supervise(children(), strategy: :one_for_one)
  end

  defp children do
    if Config.cache? do
      [
        worker(FunWithFlags.Store.Cache, [], restart: :permanent),
        FunWithFlags.Store.Persistent.adapter.worker_spec,
      ]
    else
      [
        FunWithFlags.Store.Persistent.adapter.worker_spec,
      ]
    end
  end
end
