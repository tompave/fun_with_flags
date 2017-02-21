defmodule FunWithFlags.Store.Persistent do
  @moduledoc false

  alias FunWithFlags.{Config, Notifications, Flag}

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"
  @flags_set "fun_with_flags"


  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]
    worker(Redix, [Config.redis_config, @conn_options], [restart: :permanent])
  end


  def get(flag_name) do
    case Redix.command(@conn, ["GET", format(flag_name)]) do
      {:ok, "true"}  -> true
      {:ok, "false"} -> false
      {:error, why}  -> {:error, redis_error(why)}
      _              -> false
    end
  end


  def put(flag_name, value) do
    case Redix.command(@conn, ["SET", format(flag_name), value]) do
      {:ok, "OK"} ->
        publish_change(flag_name)
        {:ok, value}
      {:error, why} -> {:error, redis_error(why)}
    end
  end


  def save(flag = %Flag{}) do
    {name, fields} = Flag.to_redis(flag)

    result = Redix.pipeline(@conn, [
      ["MULTI"],
      ["SADD", @flags_set, name],
      ["HMSET" | [format(name) | fields]],
      ["EXEC"]
    ])

    case result do
      {:ok, ["OK", "QUEUED", "QUEUED", [0, "OK"]]} ->
        publish_change(name)
        {:ok, flag}
      {:error, reason} ->
        {:error, redis_error(reason)}
      {:ok, _results} ->
        {:error, redis_error("one of the commands failed")}
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
