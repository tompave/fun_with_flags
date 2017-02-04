defmodule FunWithFlags.Store.Persistent do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end


  def init(_) do
    {:ok, []}
  end

  # def handle_info(msg, state) do
  # end

  # def handle_call() do
  # end


  # def handle_cast() do
  # end
end
