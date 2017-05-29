if Code.ensure_loaded?(Ecto) do

defmodule FunWithFlags.Store.Persistent.Ecto do
  @moduledoc false

  alias FunWithFlags.{Config, Gate, Flag}


  def worker_spec do
    nil
  end


  def get(flag_name) do
    {:ok, %Flag{name: flag_name, gates: []}}
    # {:error, "reason"}
  end


  def put(flag_name, gate = %Gate{}) do
    publish_change(flag_name)
    {:ok, %Flag{name: flag_name, gates: [gate]}}
    # {:error, "reason"}
  end


  # Deletes one gate from the Flag's Redis hash.
  # Deleting gates is idempotent and deleting unknown gates is safe.
  # A flag will continue to exist even though it has no gates.
  #
  def delete(flag_name, gate = %Gate{}) do
    publish_change(flag_name)
    {:ok, %Flag{name: flag_name, gates: []}}
    # {:error, "reason"}
  end


  # Deletes an entire Flag's Redis hash and removes its name from the Redis set.
  # Deleting flags is idempotent and deleting unknown flags is safe.
  # After the operation fetching the now-deleted flag will return the default
  # empty flag structure.
  #
  def delete(flag_name) do
    publish_change(flag_name)
    {:ok, %Flag{name: flag_name, gates: []}}
    # {:error, "reason"}
  end


  def all_flags do
    {:ok, [%Flag{name: :dummy, gates: []}]}
  end


  def all_flag_names do
    {:ok, [:dummy]}
  end


  defp publish_change(flag_name) do
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end
  end
end

end # Code.ensure_loaded?
