defmodule FunWithFlags.Store.Persistent.Redis do
  @moduledoc false

  alias FunWithFlags.{Config, Flag, Gate}
  alias FunWithFlags.Notifications.Redis, as: NotifiRedis
  alias FunWithFlags.Store.Serializer.Redis, as: Serializer

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"
  @flags_set "fun_with_flags"


  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]
    worker(Redix, [Config.redis_config, @conn_options], [restart: :permanent])
  end

  def supports_change_notifications?, do: true
  def change_notifications_listener, do: NotifiRedis


  def get(flag_name) do
    case Redix.command(@conn, ["HGETALL", format(flag_name)]) do
      {:ok, data}   -> {:ok, Serializer.flag_from_redis(flag_name, data)}
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
        {:ok, flag} = get(flag_name)
        publish_change(flag_name)
        {:ok, flag}
      {:error, reason} ->
        {:error, redis_error(reason)}
      {:ok, results} ->
        {:error, redis_error("one of the commands failed: #{inspect(results)}")}
    end
  end


  # Deletes one gate from the Flag's Redis hash.
  # Deleting gates is idempotent and deleting unknown gates is safe.
  # A flag will continue to exist even though it has no gates.
  #
  def delete(flag_name, gate = %Gate{}) do
    hash_key = format(flag_name)
    [field_key, _] = Serializer.to_redis(gate)

    case Redix.command(@conn, ["HDEL", hash_key, field_key]) do
      {:ok, _number} ->
        {:ok, flag} = get(flag_name)
        publish_change(flag_name)
        {:ok, flag}
      {:error, reason} ->
        {:error, redis_error(reason)}
    end
  end


  # Deletes an entire Flag's Redis hash and removes its name from the Redis set.
  # Deleting flags is idempotent and deleting unknown flags is safe.
  # After the operation fetching the now-deleted flag will return the default
  # empty flag structure.
  #
  def delete(flag_name) do
    result = Redix.pipeline(@conn, [
      ["MULTI"],
      ["SREM", @flags_set, flag_name],
      ["DEL", format(flag_name)],
      ["EXEC"]
    ])


    case result do
      {:ok, ["OK", "QUEUED", "QUEUED", [a, b]]} when a in [0, 1] and b in [0, 1] ->
        {:ok, flag} = get(flag_name)
        publish_change(flag_name)
        {:ok, flag}
      {:error, reason} ->
        {:error, redis_error(reason)}
      {:ok, results} ->
        {:error, redis_error("one of the commands failed: #{inspect(results)}")}
    end
  end


  def all_flags do
    {:ok, flag_names} = all_flag_names()
    flags = Enum.map(flag_names, fn(name)->
      {:ok, flag} = get(name)
      flag
    end)
    {:ok, flags}
  end


  def all_flag_names do
    {:ok, strings} = Redix.command(@conn, ["SMEMBERS", @flags_set])
    atoms = Enum.map(strings, &String.to_atom(&1))
    {:ok, atoms}
  end


  defp publish_change(flag_name) do
    if Config.cache? do
      Task.start fn() ->
        Redix.command(@conn, ["PUBLISH" | NotifiRedis.payload_for(flag_name)])
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
