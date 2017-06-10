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
    results = repo().all(query)
    flag = deserialize(flag_name, results)

    {:ok, flag}
  end


  def put(flag_name, gate = %Gate{}) do
    changeset = Record.build(flag_name, gate)

    case repo().insert(changeset, on_conflict: [set: [enabled: gate.enabled]], conflict_target: [:flag_name, :gate_type, :target]) do
      {:ok, _struct} ->
        {:ok, flag} = get(flag_name)
        publish_change(flag_name)
        {:ok, flag}
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

    {count, something} = repo().delete_all(query)
    {:ok, flag} = get(flag_name)

    publish_change(flag_name)

    {:ok, flag}
    # {:error, "reason"}
  end


  # Deletes an entire Flag's Redis hash and removes its name from the Redis set.
  # Deleting flags is idempotent and deleting unknown flags is safe.
  # After the operation fetching the now-deleted flag will return the default
  # empty flag structure.
  #
  def delete(flag_name) do
    flag_name = to_string(flag_name)

    query = from(
      r in Record,
      where: r.flag_name == ^flag_name
    )

    {count, something} = repo().delete_all(query)
    {:ok, flag} = get(flag_name)

    publish_change(flag_name)

    {:ok, flag}
    # {:error, "reason"}
  end


  def all_flags do
    flags = 
      repo().all(Record)
      |> Enum.group_by(&(&1.flag_name))
      |> Enum.map(fn ({name, records}) -> deserialize(name, records) end)
    {:ok, flags}
  end


  def all_flag_names do
    query = from(r in Record, select: r.flag_name, distinct: true)
    strings = repo().all(query)
    atoms = Enum.map(strings, &String.to_atom(&1))
    {:ok, atoms}
  end


  defp publish_change(flag_name) do
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end
  end

  defp repo, do: Config.ecto_repo()

  defp deserialize(flag_name, records) do
    Serializer.deserialize_flag(flag_name, records)
  end
end

end # Code.ensure_loaded?
