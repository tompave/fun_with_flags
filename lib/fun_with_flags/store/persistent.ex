defmodule FunWithFlags.Store.Persistent do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end


  def init(:ok) do
    {:ok, []}
  end

  # def handle_info(msg, state) do
  # end

  # def handle_call() do
  # end


  # def handle_cast() do
  # end
end
