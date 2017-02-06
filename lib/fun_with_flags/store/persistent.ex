defmodule FunWithFlags.Store.Persistent do
  @moduledoc false
  use GenServer
  alias FunWithFlags.Config

  @conn :fun_with_flags_redis
  @conn_options [name: @conn, sync_connect: false]
  @prefix "fun_with_flags:"

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def get(flag_name) do
    case Redix.command(@conn, ["GET", format(flag_name)]) do
      {:ok, "true"}  -> true
      {:ok, "false"} -> false
      _              -> false
    end
  end

  def put(flag_name, value) do
    case Redix.command(@conn, ["SET", format(flag_name), value]) do
      {:ok, "OK"} -> {:ok, value}
      {:error, _reason} = error -> error
    end
  end


  # The Redix process and its tree are linked to the current
  # Store.Persistent process, which is supervised.
  # They'll be killed and restarted automatically as well.
  #
  def init(:ok) do
    {:ok, _pid} = Redix.start_link(Config.redis_config, @conn_options)
    {:ok, nil}
  end


  defp format(flag_name) do
    @prefix <> to_string(flag_name)
  end

end
