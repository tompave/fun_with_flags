defmodule FunWithFlags.Store.Cache do
  @moduledoc """
  The in-memory cache for the feature flag, backed by an ETS table.

  This module is not meant to be used directly, but some of its functions can be
  useful to debug flag state.
  """

  @type ttl :: integer
  @type cached_at :: integer

  @doc false
  use GenServer

  alias FunWithFlags.Config
  alias FunWithFlags.Flag
  alias FunWithFlags.Timestamps

  @table_name :fun_with_flags_cache
  @table_options [
    :set, :protected, :named_table, {:read_concurrency, true}
  ]


  @doc false
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


  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end


  # We lookup without going through the GenServer
  # for concurrency and performance.
  #
  @doc false
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
  @doc false
  def put(flag = %Flag{}) do
    GenServer.call(__MODULE__, {:put, flag})
  end


  @doc """
  Clears the cache. It will be rebuilt gradually as the public interface of the
  package is queried.
  """
  @spec flush() :: true
  def flush do
    GenServer.call(__MODULE__, :flush)
  end


  @doc """
  Returns the contents of the cache ETS table, for inspection.
  """
  @spec dump() :: [{atom, {FunWithFlags.Flag.t, cached_at, ttl}}]
  def dump do
    :ets.tab2list(@table_name)
  end


  # ------------------------------------------------------------
  # GenServer callbacks


  @doc false
  def init(:ok) do
    tab_name = @table_name
    ^tab_name = :ets.new(@table_name, @table_options)
    {:ok, %{tab_name: tab_name, ttl: Config.cache_ttl}}
  end


  @doc false
  def handle_call({:put, flag = %Flag{name: name}}, _from, state = %{ttl: ttl}) do
    # writing to an ETS table will either return true or raise
    :ets.insert(@table_name, {name, {flag, Timestamps.now, ttl}})
    {:reply, {:ok, flag}, state}
  end


  @doc false
  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end
end
