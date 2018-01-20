defmodule FunWithFlags.Store.Cache do
  @moduledoc false
  use GenServer
  alias FunWithFlags.Timestamps
  alias FunWithFlags.Flag

  @table_name :fun_with_flags_cache
  @table_options [
    :set,
    :protected,
    :named_table,
    {:read_concurrency, true}
  ]
  @ttl FunWithFlags.Config.cache_ttl()

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
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
    if Timestamps.expired?(timestamp, @ttl) do
      {:miss, :expired, flag}
    else
      {:ok, flag}
    end
  end

  defp validate(_name, _flag, _timestamp) do
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
    {:ok, tab_name}
  end

  def handle_call({:put, flag = %Flag{name: name}}, _from, state) do
    reply =
      case :ets.insert(@table_name, {name, {flag, Timestamps.now()}}) do
        true -> {:ok, flag}
        _ -> {:error, error_for(flag)}
      end

    {:reply, reply, state}
  end

  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end

  defp error_for(flag) do
    "Couldn't cache the flag '#{flag.name}'"
  end
end
