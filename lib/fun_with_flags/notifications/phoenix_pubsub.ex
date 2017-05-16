if Code.ensure_loaded?(Phoenix.PubSub) do

defmodule FunWithFlags.Notifications.PhoenixPubSub do
  @moduledoc false
  use GenServer
  require Logger
  alias FunWithFlags.{Config, Store}

  # Host applications will inject this. It's supposed to be
  # an active pubsub PID or name atom.
  @conn Config.pubsub_client()
  @channel "fun_with_flags_changes"


  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]
    worker(__MODULE__, [], [restart: :permanent])
  end


  # Initialize the Genserver with a unique id (binary).
  # This id will stay with the genserver until it's terminated, and is
  # used to build the outgoing notification payloads and to ignore
  # incoming messages that originated from this node.
  #
  def start_link do
    GenServer.start_link(__MODULE__, Config.build_unique_id, [name: __MODULE__])
  end

  # Get the unique_id for this running node, which is the state
  # passed to the GenServer when it's (re)started.
  #
  def unique_id do
    {:ok, unique_id} = GenServer.call(__MODULE__, :get_unique_id)
    unique_id
  end  


  def publish_change(flag_name) do
    Task.start fn() ->
      Phoenix.PubSub.broadcast!(@conn, @channel,
        {:fwf_changes, {:updated, flag_name, unique_id()}}
      )
    end
  end


  # ------------------------------------------------------------
  # GenServer callbacks


  # The unique_id will become the state of the GenServer
  #
  def init(unique_id) do
    subscribe()
    {:ok, unique_id}
  end


  defp subscribe do
    try do
      case Phoenix.PubSub.subscribe(@conn, @channel) do
        :ok -> :ok
        {:error, reason} ->
          Logger.error "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(@conn)} ({:error, #{inspect(reason)}})."
      end
    rescue
      e ->
        Logger.error "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(@conn)} (exception: #{inspect(e)})."
    end
  end


  def handle_call(:get_unique_id, _from, unique_id) do
    {:reply, {:ok, unique_id}, unique_id}
  end


  def handle_info({:fwf_changes, {:updated, _name, unique_id}}, unique_id) do
    # received my own message, doing nothing
    {:noreply, unique_id}
  end

  def handle_info({:fwf_changes, {:updated, name, _}}, unique_id) do
    # received message from another node, reload the flag
    Logger.debug("FunWithFlags: received change notifiation for flag '#{name}'")
    Task.start(Store, :reload, [name])
    {:noreply, unique_id}
  end
end

end # Code.ensure_loaded?
