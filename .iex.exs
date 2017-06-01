import FunWithFlags
alias FunWithFlags.{Store,Config,Flag,Gate}
alias FunWithFlags.Store.{Cache,Persistent,Serializer}
alias FunWithFlags.{Actor,Group}

alias FunWithFlags.Dev.EctoRepo, as: Repo
alias FunWithFlags.Store.Persistent.Ecto.Schema, as: Model

if Config.persist_in_ecto? do
  {:ok, _pid} = FunWithFlags.Dev.EctoRepo.start_link()
else
  {:ok, redis} =
    Redix.start_link(
      Config.redis_config,
      [name: :dev_console_redis, sync_connect: false])
end

if Config.phoenix_pubsub? do
  {:ok, _pid} = Phoenix.PubSub.PG2.start_link(:fwf_test, [pool_size: 1])
end


cacheinfo = fn() ->
  size = :ets.info(:fun_with_flags_cache)[:size]
  IO.puts "size: #{size}"
  :ets.i(:fun_with_flags_cache)
end
