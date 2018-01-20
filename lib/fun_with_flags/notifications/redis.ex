if Code.ensure_loaded?(Redix.PubSub) do
  defmodule FunWithFlags.Notifications.Redis do
    @moduledoc false
    use GenServer
    require Logger
    alias FunWithFlags.{Config, Store}

    # Use the Redis conn from the persistence module to
    # issue redis commands (to publish notification).
    @write_conn FunWithFlags.Store.Persistent.Redis

    @conn :fun_with_flags_notifications
    @conn_options [name: @conn, sync_connect: false]
    @channel "fun_with_flags_changes"

    def worker_spec do
      import Supervisor.Spec, only: [worker: 3]
      worker(__MODULE__, [], restart: :permanent)
    end

    # Initialize the Genserver with a unique id (binary).
    # This id will stay with the genserver until it's terminated, and is
    # used to build the outgoing notification payloads and to ignore
    # incoming messages that originated from this node.
    #
    def start_link do
      GenServer.start_link(__MODULE__, Config.build_unique_id(), name: __MODULE__)
    end

    # Get the unique_id for this running node, which is the state
    # passed to the GenServer when it's (re)started.
    #
    def unique_id do
      {:ok, unique_id} = GenServer.call(__MODULE__, :get_unique_id)
      unique_id
    end

    # Build a payload to be passed to Redis.
    # Must go through the GenServer because we need the unique_id
    # stored in its state.
    #
    @spec payload_for(atom) :: [String.t()]
    def payload_for(flag_name) do
      [@channel, "#{unique_id()}:#{to_string(flag_name)}"]
    end

    def publish_change(flag_name) do
      Task.start(fn ->
        Redix.command(@write_conn, ["PUBLISH" | payload_for(flag_name)])
      end)
    end

    # ------------------------------------------------------------
    # GenServer callbacks

    # The unique_id will become the state of the GenServer
    #
    def init(unique_id) do
      {:ok, _pid} = Redix.PubSub.start_link(Config.redis_config(), @conn_options)
      :ok = Redix.PubSub.subscribe(@conn, @channel, self())
      {:ok, unique_id}
    end

    def handle_call(:get_unique_id, _from, unique_id) do
      {:reply, {:ok, unique_id}, unique_id}
    end

    def handle_info({:redix_pubsub, _from, :subscribed, %{channel: @channel}}, unique_id) do
      {:noreply, unique_id}
    end

    def handle_info({:redix_pubsub, _from, :unsubscribed, %{channel: @channel}}, unique_id) do
      {:noreply, unique_id}
    end

    def handle_info({:redix_pubsub, _from, :disconnected, %{error: error}}, unique_id) do
      Logger.error(
        "FunWithFlags: Redis pub-sub connection interrupted, reason: '#{
          Redix.ConnectionError.message(error)
        }'."
      )

      {:noreply, unique_id}
    end

    # 1/2
    # Another node has updated a flag and published an event.
    # We react to it by validating the unique_id in the message.
    #
    def handle_info(
          {:redix_pubsub, _from, :message, %{channel: @channel, payload: msg}},
          unique_id
        ) do
      validate_message(msg, unique_id)
      {:noreply, unique_id}
    end

    # 2/2
    # If it matches our unique_id, then it originated from this node
    # and we don't need to reload the cached flag.
    # If it doesn't match, on the other hand, we need to reload it.
    #
    defp validate_message(msg, unique_id) do
      case String.split(msg, ":") do
        [^unique_id, _name] ->
          # received my own message, doing nothing
          nil

        [_id, name] ->
          # received message from another node, reload the flag
          Logger.debug("FunWithFlags: received change notifiation for flag '#{name}'")
          Task.start(Store, :reload, [String.to_atom(name)])

        _ ->
          # invalid message, ignore
          nil
      end
    end
  end
end

# Code.ensure_loaded?
