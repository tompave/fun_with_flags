if Code.ensure_loaded?(Ecto) do

defmodule FunWithFlags.Store.Persistent.Ecto do
  @moduledoc false

  alias FunWithFlags.{Config, Gate, Flag}
  alias FunWithFlags.Store.Persistent.Ecto.Record
  alias FunWithFlags.Store.Serializer.Ecto, as: Serializer

  import Ecto.Query

  def worker_spec do
    nil
  end


  def get(flag_name) do
    name_string = to_string(flag_name)
    
    query = from r in Record, where: r.flag_name == ^name_string
    repo = Config.ecto_repo()
    results = repo.all(query)
    flag = Serializer.deserialize_flag(flag_name, results)

    {:ok, flag}
  end


  def put(flag_name, gate = %Gate{}) do
    changeset = Record.build(flag_name, gate)
    repo = Config.ecto_repo()

    case repo.insert(changeset) do
      {:ok, _struct} ->
        publish_change(flag_name)
        {:ok, nil}
      {:error, changeset} ->
        {:error, changeset.errors}
    end
  end


  # Deletes one gate from the Flag's Redis hash.
  # Deleting gates is idempotent and deleting unknown gates is safe.
  # A flag will continue to exist even though it has no gates.
  #
  def delete(flag_name, gate = %Gate{}) do
    flag_name = to_string(flag_name)
    gate_type = to_string(gate.type)
    target    = to_string(gate.for)

    query = from(
      r in Record,
      where: r.flag_name == ^flag_name
      and r.gate_type == ^gate_type
      and r.target == ^target
    )
    repo = Config.ecto_repo()

    {count, something} = repo.delete_all(query)

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
