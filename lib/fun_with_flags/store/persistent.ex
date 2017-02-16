defmodule FunWithFlags.Store.Persistent do
  @moduledoc false

  alias FunWithFlags.Config

  @conn __MODULE__
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"


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
      {:ok, "OK"} -> {:ok, value}
      {:error, why} -> {:error, redis_error(why)}
    end
  end


  defp format(flag_name) do
    @prefix <> to_string(flag_name)
  end

  defp redis_error(reason_atom) do
    "Redis Error: #{reason_atom}"
  end

end
