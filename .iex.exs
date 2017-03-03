import FunWithFlags
alias FunWithFlags.{Store,Config,Flag,Gate}
alias FunWithFlags.Store.{Cache,Persistent,Serializer}
alias FunWithFlags.Actor

{:ok, redis} =
  Redix.start_link(
    Config.redis_config,
    [name: :dev_console_redis, sync_connect: false])


cacheinfo = fn() ->
  size = :ets.info(:fun_with_flags_cache)[:size]
  IO.puts "size: #{size}"
  :ets.i(:fun_with_flags_cache)
end
