if Code.ensure_loaded?(Redix) do

defmodule FunWithFlags.Store.Persistent.Redis do
  @moduledoc false

  alias FunWithFlags.{Config, Gate}
  alias FunWithFlags.Store.Serializer.Redis, as: Serializer

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"
  @flags_set "fun_with_flags"


  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]

    conf = case Config.redis_config do
      uri when is_binary(uri) ->
        [uri, @conn_options]
      opts when is_list(opts) ->
        [Keyword.merge(opts, @conn_options)]
    end

    worker(Redix, conf, [restart: :permanent])
  end

  def get(flag_name) do
    case Redix.command(@conn, ["HGETALL", format(flag_name)]) do
      {:ok, data}   -> {:ok, Serializer.deserialize_flag(flag_name, data)}
      {:error, why} -> {:error, redis_error(why)}
      _             -> {:error, :unknown}
    end
  end


  def put(flag_name, gate = %Gate{}) do
    data = Serializer.serialize(gate)

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
    [field_key, _] = Serializer.serialize(gate)

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
    flags = Enum.map(flag_names, fn(name) ->
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
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end
  end


  defp format(flag_name) do
    @prefix <> to_string(flag_name)
  end

  defp redis_error(reason_atom) do
    "Redis Error: #{reason_atom}"
  end
end

end # Code.ensure_loaded?
