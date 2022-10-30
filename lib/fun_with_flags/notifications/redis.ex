if Code.ensure_loaded?(Redix.PubSub) do

defmodule FunWithFlags.Notifications.Redis do
  @moduledoc false
  use GenServer
  require Logger
  alias FunWithFlags.{Config, Store}

  # Use the Redis conn from the persistence module to
  # issue Redis commands (to publish notification).
  @write_conn FunWithFlags.Store.Persistent.Redis

  @conn :fun_with_flags_notifications
  @conn_options [name: @conn, sync_connect: false]
  @channel "fun_with_flags_changes"

  # Retrieve the configuration to connect to Redis, and package it as an argument
  # to be passed to the start_link function.
  #
  def worker_spec do
    redis_conn_config = case Config.redis_config do
      uri when is_binary(uri) ->
        {uri, @conn_options}
      {uri, opts} when is_binary(uri) and is_list(opts) ->
        {uri, Keyword.merge(opts, @conn_options)}
      opts when is_list(opts) ->
        Keyword.merge(opts, @conn_options)
    end

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [redis_conn_config]},
      restart: :permanent,
      type: :worker,
    }
  end


  # Initialize the GenServer with a unique id (binary).
  # This id will stay with the GenServer until it's terminated, and is
  # used to build the outgoing notification payloads and to ignore
  # incoming messages that originated from this node.
  #
  def start_link(redis_conn_config) do
    GenServer.start_link(__MODULE__, {redis_conn_config, Config.build_unique_id}, [name: __MODULE__])
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
  @spec payload_for(atom) :: [String.t]
  def payload_for(flag_name) do
    [@channel, "#{unique_id()}:#{to_string(flag_name)}"]
  end


  def publish_change(flag_name) do
    Logger.debug fn -> "FunWithFlags.Notifications: publish change for '#{flag_name}'" end
    Task.start fn() ->
      Redix.command(
        @write_conn,
        ["PUBLISH" | payload_for(flag_name)]
      )
    end
  end

  # ------------------------------------------------------------
  # GenServer callbacks


  # The unique_id will become the state of the GenServer
  #
  def init({redis_conn_config, unique_id}) do
    {:ok, _pid} = case redis_conn_config do
      {uri, opts} when is_binary(uri) and is_list(opts) ->
        Redix.PubSub.start_link(uri, opts)
      opts when is_list(opts) ->
        Redix.PubSub.start_link(opts)
    end

    {:ok, ref} = Redix.PubSub.subscribe(@conn, @channel, self())
    state = {unique_id, ref}
    {:ok, state}
  end


  def handle_call(:get_unique_id, _from, state = {unique_id, _ref}) do
    {:reply, {:ok, unique_id}, state}
  end


  def handle_info({:redix_pubsub, _from, ref, :subscribed, %{channel: @channel}}, state = {_, ref}) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _from, ref, :unsubscribed, %{channel: @channel}}, state = {_, ref}) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _from, ref, :disconnected, %{error: error}}, state = {_, ref}) do
    Logger.error("FunWithFlags: Redis pub-sub connection interrupted, reason: '#{Redix.ConnectionError.message(error)}'.")
    {:noreply, state}
  end


  # 1/2
  # Another node has updated a flag and published an event.
  # We react to it by validating the unique_id in the message.
  #
  def handle_info({:redix_pubsub, _from, ref, :message, %{channel: @channel, payload: msg}}, state = {unique_id, ref}) do
    validate_message(msg, unique_id)
    {:noreply, state}
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
        Logger.debug fn -> "FunWithFlags: received change notification for flag '#{name}'" end
        Task.start(Store, :reload, [String.to_atom(name)])
      _ ->
        # invalid message, ignore
        nil
    end

  end
end

end # Code.ensure_loaded?
