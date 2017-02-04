defmodule FunWithFlags.Store.Cache do
  use GenServer

  @table_name :fun_with_flags_cache
  @table_options [
    :set, :protected, :named_table, {:read_concurrency, true}
  ]

  def start_link do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  # We lookup without going through the GenServer
  # for concurrency and perfomance.
  #
  def get(flag_name) do
    case :ets.lookup(@table_name, flag_name) do
      [{^flag_name, value}] -> value
      _ -> false
    end
  end

  # We want to always write serially though the
  # GenServer to avoid race conditions.
  #
  def put(flag_name, value) do
    GenServer.call(__MODULE__, {:put, flag_name, value})
  end


  # ------------------------------------------------------------
  # GenServer callbacks


  def init(_) do
    tab_name = @table_name
    ^tab_name = create_table()
    {:ok, tab_name}
  end

  # def handle_info(msg, state) do
  # end

  def handle_call({:put, flag_name, value}, _from, state) do
    reply = case :ets.insert(@table_name, {flag_name, value}) do
      true -> {:ok, value}
      _    -> {:error, set_error_for(value)}
    end
    {:reply, reply, state}
  end


  # def handle_cast() do
  # end


  defp create_table do
    :ets.new(@table_name, @table_options)
  end


  defp set_error_for(value) do
    if value do
      "couldn't enable the flag"
    else
      "couldn't disable the flag"
    end
  end
end
