if Code.ensure_loaded?(Phoenix.PubSub) do

defmodule FunWithFlags.Notifications.PhoenixPubSub do
  @moduledoc false
  use GenServer
  require Logger
  alias FunWithFlags.{Config, Store}

  @channel "fun_with_flags_changes"
  @max_attempts 5


  def worker_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :permanent,
      type: :worker,
    }
  end


  # Initialize the GenServer with a unique id (binary).
  # This id will stay with the GenServer until it's terminated, and is
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

  # Get the pubsub subscription status for the current note, which tells us if
  # the GenServer for this module has successfully completed the Phoenix.PubSub
  # subscription procedure to the change notification topic.
  #
  # The GenServer might still be unsubscribed if this is called very early
  # after the application has started. (i.e. in some unit tests), but in general
  # a runtime exception is raised if subscribing is not completed within a few
  # seconds.
  #
  def subscribed? do
    {:ok, subscription_status} = GenServer.call(__MODULE__, :get_subscription_status)
    subscription_status == :subscribed
  end


  def publish_change(flag_name) do
    Logger.debug fn -> "FunWithFlags.Notifications: publish change for '#{flag_name}'" end
    Task.start fn() ->
      Phoenix.PubSub.broadcast!(client(), @channel,
        {:fwf_changes, {:updated, flag_name, unique_id()}}
      )
    end
  end


  # ------------------------------------------------------------
  # GenServer callbacks


  # The unique_id will become the state of the GenServer
  #
  def init(unique_id) do
    subscription_status = subscribe(1)
    {:ok, {unique_id, subscription_status}}
  end


  defp subscribe(attempt) when attempt <= @max_attempts do
    try do
      case Phoenix.PubSub.subscribe(client(), @channel) do
        :ok ->
          # All good
          Logger.debug fn -> "FunWithFlags: Connected to Phoenix.PubSub process #{inspect(client())}" end
          :subscribed
        {:error, reason} ->
          # Handled application errors
          Logger.debug fn -> "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(client())} ({:error, #{inspect(reason)}})." end
          try_again_to_subscribe(attempt)
          :unsubscribed
      end
    rescue
      e ->
        # The pubsub process was probably not running. This happens when using it in Phoenix, as it tries to connect the
        # first time while the application is booting, and the Phoenix.PubSub process is not fully started yet.
        Logger.debug fn -> "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(client())} (exception: #{inspect(e)})." end
        try_again_to_subscribe(attempt)
        :unsubscribed
    end
  end


  # We can't connect to the PubSub process. Possibly because it didn't start.
  #
  defp subscribe(_) do
    raise "Tried to subscribe to Phoenix.PubSub process #{inspect(client())} #{@max_attempts} times. Giving up."
  end


  # Wait 1 second and try again
  #
  defp try_again_to_subscribe(attempt) do
    Process.send_after(self(), {:subscribe_retry, (attempt + 1)}, 1000)
  end


  def handle_call(:get_unique_id, _from, state = {unique_id, _subscription_status}) do
    {:reply, {:ok, unique_id}, state}
  end

  def handle_call(:get_subscription_status, _from, state = {_unique_id, subscription_status}) do
    {:reply, {:ok, subscription_status}, state}
  end

  # Test helper
  #
  def handle_call({:test_helper_set_subscription_status, new_subscription_status}, _from, {unique_id, _current_subscription_status}) do
    {:reply, :ok, {unique_id, new_subscription_status}}
  end


  def handle_info({:fwf_changes, {:updated, _name, unique_id}}, state = {unique_id, _subscription_status}) do
    # received my own message, doing nothing
    {:noreply, state}
  end

  def handle_info({:fwf_changes, {:updated, name, _}}, state) do
    # received message from another node, reload the flag
    Logger.debug fn -> "FunWithFlags: received change notification for flag '#{name}'" end
    Task.start(Store, :reload, [name])
    {:noreply, state}
  end


  # When subscribing to the pubsub process fails, the process sends itself a delayed message
  # to try again. It will be handled here.
  #
  def handle_info({:subscribe_retry, attempt}, state = {unique_id, _subscription_status}) do
    Logger.debug fn -> "FunWithFlags: retrying to subscribe to Phoenix.PubSub, attempt #{attempt}." end
    case subscribe(attempt) do
      :subscribed ->
        Logger.debug fn -> "FunWithFlags: updating Phoenix.PubSub's subscription status to :subscribed." end
        {:noreply, {unique_id, :subscribed}}
      _ ->
        # don't change the state
        {:noreply, state}
    end
  end

  defp client, do: Config.pubsub_client()
end

end # Code.ensure_loaded?
