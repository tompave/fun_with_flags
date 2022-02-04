if Code.ensure_loaded?(Phoenix.PubSub) do

defmodule FunWithFlags.Notifications.PhoenixPubSub do
  @moduledoc false
  use GenServer
  use Timex
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
    wait_for_phoenix_pubsub_before_subscribing(now())
    {:ok, unique_id}
  end


  defp subscribe(attempt) when attempt <= @max_attempts do
    try do
      case Phoenix.PubSub.subscribe(client(), @channel) do
        :ok ->
          # All good
          Logger.debug fn -> "FunWithFlags: Connected to Phoenix.PubSub process #{inspect(client())}" end
          :ok
        {:error, reason} ->
          # Handled application errors
          Logger.debug fn -> "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(client())} ({:error, #{inspect(reason)}})." end
          try_again_to_subscribe(attempt)
      end
    rescue
      e ->
        # The pubsub process was probably not running. This happens when using it in Phoenix, as it tries to connect the
        # first time while the application is booting, and the Phoenix.PubSub process is not fully started yet.
        Logger.debug fn -> "FunWithFlags: Cannot subscribe to Phoenix.PubSub process #{inspect(client())} (exception: #{inspect(e)})." end
        try_again_to_subscribe(attempt)
    end
  end


  # We can't connect to the PubSub process. Possibly because it didn't start.
  #
  defp subscribe(_) do
    raise "Tried to subscribe to Phoenix.PubSub process #{inspect(client())} #{@max_attempts} times. Giving up."
  end

  defp wait_for_phoenix_pubsub_before_subscribing(since, attempt \\ 0) do
    case Process.whereis(client()) do
      nil ->
        if attempt > 1 do
          duration = now() - since
          humanized = Duration.from_milliseconds(ceil_nearest(duration, 1000)) |> Elixir.Timex.Format.Duration.Formatters.Humanized.format
          Logger.debug fn -> "FunWithFlags: Patiently waiting #{humanized} for the Phoenix.PubSub process to start." end
        end
        Process.send_after(self(), {:wait_for_phoenix_pubsub_retry, since, (attempt + 1)}, 1000)

      _ ->
        if attempt > 1 do
          Logger.debug fn -> "FunWithFlags: Detected Phoenix.PubSub process." end
        end
        subscribe(1)
    end
  end

  # Wait 1 second and try again
  #
  defp try_again_to_subscribe(attempt) do
    Process.send_after(self(), {:subscribe_retry, (attempt + 1)}, 1000)
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
    Logger.debug fn -> "FunWithFlags: received change notification for flag '#{name}'" end
    Task.start(Store, :reload, [name])
    {:noreply, unique_id}
  end


  # When subscribing to the pubsub process fails, the process sends itself a delayed message
  # to try again. It will be handled here.
  #
  def handle_info({:subscribe_retry, attempt}, unique_id) do
    Logger.debug fn -> "FunWithFlags: retrying to subscribe to Phoenix.PubSub, attempt #{attempt}." end
    subscribe(attempt)
    {:noreply, unique_id}
  end

  def handle_info({:wait_for_phoenix_pubsub_retry, since, attempt}, unique_id) do
    wait_for_phoenix_pubsub_before_subscribing(since, attempt)
    {:noreply, unique_id}
  end

  defp client, do: Config.pubsub_client()
  defp now, do: System.monotonic_time(:millisecond)
  def ceil_nearest(num, target), do: ceil(num/target)*target
end

end # Code.ensure_loaded?
