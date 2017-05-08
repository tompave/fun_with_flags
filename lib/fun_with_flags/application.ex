defmodule FunWithFlags.Application do
  @moduledoc false

  use Application

  import Supervisor.Spec

  alias FunWithFlags.Store.Persistent
  alias FunWithFlags.Config

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: FunWithFlags.Supervisor]
    IO.puts "Caching: #{inspect Config.cache?}"
    IO.puts "Our children will be: #{inspect worker_spec_with_caching(Config.cache?)}"
    Supervisor.start_link(worker_spec_with_caching(Config.cache?), opts)
  end


  defp worker_spec_with_caching(true) do
    [ worker(FunWithFlags.Store.Cache, [], restart: :permanent) ]
    ++ Persistent.adapter.worker_spec(:with_notifications)
  end

  defp worker_spec_with_caching(_) do
    Persistent.adapter.worker_spec(:without_notifications)
  end
end
