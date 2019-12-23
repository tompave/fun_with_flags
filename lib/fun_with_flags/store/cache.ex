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
      [{^flag_name, {flag, timestamp, ttl}}] ->
        validate(flag_name, flag, timestamp, ttl)
      _ ->
        {:miss, :not_found, nil}
    end
  end

  defp validate(name, flag = %Flag{name: name}, timestamp, ttl) do
    if Timestamps.expired?(timestamp, ttl) do
      {:miss, :expired, flag}
    else
      {:ok, flag}
    end
  end
  defp validate(_name, _flag, _timestamp, _ttl) do
    {:miss, :invalid, nil}
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
    {:ok, %{tab_name: tab_name, ttl: Config.cache_ttl}}
  end


  def handle_call({:put, flag = %Flag{name: name}}, _from, state = %{ttl: ttl}) do
    # writing to an ETS table will either return true or raise
    :ets.insert(@table_name, {name, {flag, Timestamps.now, ttl}})
    {:reply, {:ok, flag}, state}
  end


  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end
end
