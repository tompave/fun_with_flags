defmodule FunWithFlags.Store.Persistent do
  use GenServer

  @conn_name :fun_with_flags_redis

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end


  # The Redix process and its tree are linked to the current
  # Store.Persistent process, which is supervised.
  # They'll be killed and restarted automatically as well.
  #
  def init(:ok) do
    Redix.start_link([], [name: @conn_name])
    {:ok, []}
  end

  # def handle_info(msg, state) do
  # end

  # def handle_call() do
  # end


  # def handle_cast() do
  # end
end
