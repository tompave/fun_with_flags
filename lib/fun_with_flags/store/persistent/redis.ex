if Code.ensure_loaded?(Redix) do

defmodule FunWithFlags.Store.Persistent.Redis do
  @moduledoc false

  @behaviour FunWithFlags.Store.Persistent

  alias FunWithFlags.{Config, Gate}
  alias FunWithFlags.Store.Serializer.Redis, as: Serializer

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"
  @flags_set "fun_with_flags"


  @impl true
  def worker_spec do
    conf = case Config.redis_config do
      uri when is_binary(uri) ->
        {uri, @conn_options}
      opts when is_list(opts) ->
        Keyword.merge(opts, @conn_options)
    end

    Redix.child_spec(conf)
  end


  @impl true
  def get(flag_name) do
    case Redix.command(@conn, ["HGETALL", format(flag_name)]) do
      {:ok, data}   -> {:ok, Serializer.deserialize_flag(flag_name, data)}
      {:error, why} -> {:error, redis_error(why)}
    end
  end


  @impl true
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
  @impl true
  def delete(flag_name, gate = %Gate{}) do
    hash_key = format(flag_name)
    [field_key, _] = Serializer.serialize(gate)

    case Redix.command(@conn, ["HDEL", hash_key, field_key]) do
      {:ok, _number} ->
        {:ok, flag} = get(flag_name)
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
  @impl true
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
        {:ok, flag}
      {:error, reason} ->
        {:error, redis_error(reason)}
      {:ok, results} ->
        {:error, redis_error("one of the commands failed: #{inspect(results)}")}
    end
  end


  @impl true
  def all_flags do
    case all_flag_names() do
      {:ok, flag_names} -> materialize_flags_from_names(flag_names)
      error -> error
    end
  end

  defp materialize_flags_from_names(flag_names) do
    flags = Enum.map(flag_names, fn(name) ->
      case get(name) do
        {:ok, flag} -> flag
        error -> error
      end
    end)
    {:ok, flags}
  end


  @impl true
  def all_flag_names do
    case Redix.command(@conn, ["SMEMBERS", @flags_set]) do
      {:ok, strings} ->
        atoms = Enum.map(strings, &String.to_atom(&1))
        {:ok, atoms}
      {:error, reason} ->
        {:error, redis_error(reason)}
    end
  end


  defp format(flag_name) do
    @prefix <> to_string(flag_name)
  end

  defp redis_error(%Redix.ConnectionError{reason: reason_atom}) do
    "Redis Connection Error: #{reason_atom}"
  end

  defp redis_error(%Redix.Error{message: message}) do
    "Redis Error: #{message}"
  end

  defp redis_error(reason_atom) do
    "Redis Error: #{reason_atom}"
  end
end

end # Code.ensure_loaded?
