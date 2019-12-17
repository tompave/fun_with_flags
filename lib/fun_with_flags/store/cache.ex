defmodule FunWithFlags.Store.Cache do
  @moduledoc false
  use GenServer
  alias FunWithFlags.Timestamps
  alias FunWithFlags.Flag
  alias FunWithFlags.Config

  @table_name :fun_with_flags_cache
  @table_options [
    :set, :protected, :named_table, {:read_concurrency, true}
  ]
  @ttl Config.cache_ttl


  def worker_spec do
    if FunWithFlags.Config.cache? do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, []},
        restart: :permanent,
        type: :worker,
      }
    end
  end


  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end


  # We lookup without going through the GenServer
  # for concurrency and perfomance.
  #
  def get(flag_name) do
    case :ets.lookup(@table_name, flag_name) do
      [{^flag_name, {flag, timestamp}}] ->
        validate(flag_name, flag, timestamp)
      _ ->
        {:miss, :not_found, nil}
    end
  end

  defp validate(name, flag = %Flag{name: name}, timestamp) do
    if flag_stale?(timestamp, name) do
      {:miss, :expired, flag}
    else
      {:ok, flag}
    end
  end
  defp validate(_name, _flag, _timestamp) do
    {:miss, :invalid, nil}
  end

  defp flag_stale?(timestamp, flag_name) do
    ttl = Config.cache_ttl
    if Config.cache_flutter? do
      g = Timestamps.expired?(timestamp, ttl, flutter_offset(flag_name))
      # IO.inspect(g)

      g
    else
      Timestamps.expired?(timestamp, ttl)
    end
  end

  defp flutter_offset(flag_name) do
    flutter_percentage = 0.1
    maximum_ttl_variance = ceil(@ttl * flutter_percentage)

    flag_name
    |> flag_name_as_integer()
    |> Integer.mod(maximum_ttl_variance)
    |> Kernel.*(-1)
  end

  defp flag_name_as_integer(flag_name) do
    {name_as_integer, _} =
      :crypto.hash(:md5, Atom.to_string(flag_name))
      |> Base.encode16()
      |> Integer.parse(16)

    name_as_integer
  end

  # We want to always write serially through the
  # GenServer to avoid race conditions.
  #
  def put(flag = %Flag{}) do
    GenServer.call(__MODULE__, {:put, flag})
  end


  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  def dump do
    :ets.tab2list(@table_name)
  end

  # ------------------------------------------------------------
  # GenServer callbacks


  def init(:ok) do
    tab_name = @table_name
    ^tab_name = :ets.new(@table_name, @table_options)
    {:ok, tab_name}
  end


  def handle_call({:put, flag = %Flag{name: name}}, _from, state) do
    # writing to an ETS table will either return true or raise
    :ets.insert(@table_name, {name, {flag, Timestamps.now}})
    {:reply, {:ok, flag}, state}
  end


  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end
end
