defmodule FunWithFlags.Store.Cache do
  use GenServer

  @table_name :fun_with_flags

  def start_link do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end


  def init(_) do
    tab_name = @table_name
    ^tab_name = create_table()
    {:ok, tab_name}
  end

  # def handle_info(msg, state) do
  # end

  # def handle_call() do
  # end


  # def handle_cast() do
  # end


  # This
  # optionally set "{:read_concurrency, true}"
  #
  defp create_table do
    :ets.new(@table_name, [:set, :public, :named_table])
  end
end
