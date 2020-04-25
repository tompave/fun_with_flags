import FunWithFlags
alias FunWithFlags.{Store,Config,Flag,Gate}
alias FunWithFlags.Store.{Cache,Persistent,Serializer}
alias FunWithFlags.{Actor,Group}

alias FunWithFlags.Dev.EctoRepo, as: Repo
alias FunWithFlags.Store.Persistent.Ecto.Record


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
