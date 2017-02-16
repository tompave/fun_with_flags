defmodule FunWithFlags.Notifications do
  @moduledoc false
  use GenServer
  alias FunWithFlags.Config

  @conn :fun_with_flags_notifications
  @conn_options [name: @conn, sync_connect: false]
  @channel "fun_with_flags_changes"


  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  # ------------------------------------------------------------
  # GenServer callbacks

  def init(:ok) do
    {:ok, _pid} = Redix.PubSub.start_link(Config.redis_config, @conn_options)
    :ok = Redix.PubSub.subscribe(@conn, @channel, self())
    {:ok, nil}
  end

  def handle_info({:redix_pubsub, _from, :subscribed, %{channel: "fun_with_flags_changes"}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _from, :message, %{channel: "fun_with_flags_changes", payload: msg}}, state) do
    IO.puts "Received PubSub message: #{inspect(msg)}"
    {:noreply, state}
  end
end
