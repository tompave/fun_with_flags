defmodule FunWithFlags.Store.Persistent do
  @moduledoc false

  alias FunWithFlags.{Config, Notifications, Flag, Gate}
  alias FunWithFlags.Store.Serializer

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"
  @flags_set "fun_with_flags"


  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]
    worker(Redix, [Config.redis_config, @conn_options], [restart: :permanent])
  end


  def get(flag_name) do
    case Redix.command(@conn, ["HGETALL", format(flag_name)]) do
      {:ok, data}   -> Flag.from_redis(flag_name, data)
      {:error, why} -> {:error, redis_error(why)}
      _             -> {:error, :unknown}
    end
  end


  def put(flag_name, gate = %Gate{}) do
    data = Serializer.to_redis(gate)

    result = Redix.pipeline(@conn, [
      ["MULTI"],
      ["SADD", @flags_set, flag_name],
      ["HSET" | [format(flag_name) | data]],
      ["EXEC"]
    ])

    case result do
      {:ok, ["OK", "QUEUED", "QUEUED", [a, b]]} when a in [0, 1] and b in [0, 1] ->
        publish_change(flag_name)
        {:ok, gate}
      {:error, reason} ->
        {:error, redis_error(reason)}
      {:ok, results} ->
        {:error, redis_error("one of the commands failed: #{inspect(results)}")}
    end
  end


  def publish_change(flag_name) do
    if Config.cache? do
      Task.start fn() ->
        Redix.command(@conn, ["PUBLISH" | Notifications.payload_for(flag_name)])
      end
    end
  end


  defp format(flag_name) do
    @prefix <> to_string(flag_name)
  end

  defp redis_error(reason_atom) do
    "Redis Error: #{reason_atom}"
  end

end
