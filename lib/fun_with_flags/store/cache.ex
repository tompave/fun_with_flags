defmodule FunWithFlags.Store.Cache do
  @moduledoc false
  use GenServer
  alias FunWithFlags.Timestamps

  @table_name :fun_with_flags_cache
  @table_options [
    :set, :protected, :named_table, {:read_concurrency, true}
  ]
  @ttl FunWithFlags.Config.cache_ttl

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  
  # We lookup without going through the GenServer
  # for concurrency and perfomance.
  #
  def get(flag_name) do
    case :ets.lookup(@table_name, flag_name) do
      [{^flag_name, {value, timestamp}}] ->
        validate_expiration(value, timestamp)
      _ ->
        {:miss, :not_found, nil}
    end
  end

  defp validate_expiration(value, timestamp) do
    if Timestamps.expired?(timestamp, @ttl) do
      {:miss, :expired, value}
    else
      {:ok, value}
    end
  end


  # We want to always write serially through the
  # GenServer to avoid race conditions.
  #
  def put(flag_name, value) do
    GenServer.call(__MODULE__, {:put, flag_name, value})
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


  def handle_call({:put, flag_name, value}, _from, state) do
    reply = case :ets.insert(@table_name, {flag_name, {value, Timestamps.now}}) do
      true -> {:ok, value}
      _    -> {:error, set_error_for(value)}
    end
    {:reply, reply, state}
  end


  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end
  

  defp set_error_for(value) do
    if value do
      "couldn't enable the flag"
    else
      "couldn't disable the flag"
    end
  end
end
