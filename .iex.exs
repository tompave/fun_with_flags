import FunWithFlags
alias FunWithFlags.{Store,Config,Flag,Gate}
alias FunWithFlags.Store.{Cache,Persistent,Serializer}
alias FunWithFlags.{Actor,Group}

alias FunWithFlags.Dev.EctoRepo, as: Repo
alias FunWithFlags.Store.Persistent.Ecto.Record
alias FunWithFlags.Supervisor, as: Sup


# When calling `respawn` in a iex session, e.g. debugging tests,
# the .iex.exs file will be parsed and executed again, and
# these `start_link` with explicit names will fail as already
# started.
#
with_safe_restart = fn(f) ->
  case f.() do
    {:ok, _pid} ->
      # IO.puts "starting"
      :ok
    {:error, {:already_started, _pid}} ->
      # IO.puts "already started"
      :ok
  end
end

if Config.persist_in_ecto? do
  with_safe_restart.(fn ->
    FunWithFlags.Dev.EctoRepo.start_link()
  end)
else
  with_safe_restart.(fn ->
    Redix.start_link(
      Keyword.merge(
        Config.redis_config,
        [name: :dev_console_redis, sync_connect: false]
      )
    )
  end)
end

if Config.phoenix_pubsub? do
  with_safe_restart.(fn ->
    children = [
      {Phoenix.PubSub, [name: :fwf_test, adapter: Phoenix.PubSub.PG2, pool_size: 1]}
    ]
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end)
end

alias FunWithFlags.Store.Persistent.Ecto, as: PEcto

cacheinfo = fn() ->
  size = :ets.info(:fun_with_flags_cache)[:size]
  IO.puts "size: #{size}"
  :ets.i(:fun_with_flags_cache)
end

# Start the FWF Supervision tree as a child of the IEx application.
# This makes it a bit more convenient to visualize the supervision tree in the
# observer tool. (`:observer.start()`)
#
Supervisor.start_child(IEx.Supervisor, {FunWithFlags.Supervisor, []})
#
# Or starting it directly also works:
#
# FunWithFlags.Supervisor.start_link(nil)

# Enable this to work with telemetry events:
#
# FunWithFlags.Telemetry.attach_debug_handler()
