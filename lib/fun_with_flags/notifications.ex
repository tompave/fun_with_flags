defmodule FunWithFlags.Notifications do
  @moduledoc false
  use GenServer
  alias FunWithFlags.{Config, Store}

  @conn :fun_with_flags_notifications
  @conn_options [name: @conn, sync_connect: false]
  @channel "fun_with_flags_changes"


  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def channel, do: @channel


  # ------------------------------------------------------------
  # GenServer callbacks

  def init(:ok) do
    {:ok, _pid} = Redix.PubSub.start_link(Config.redis_config, @conn_options)
    :ok = Redix.PubSub.subscribe(@conn, @channel, self())
    {:ok, nil}
  end

  def handle_info({:redix_pubsub, _from, :subscribed, %{channel: @channel}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _from, :message, %{channel: @channel, payload: msg}}, state) do
    IO.puts "Received PubSub message: #{inspect(msg)}"
    flag_name = String.to_atom(msg)
    Store.reload(flag_name)
    {:noreply, state}
  end
end
