if Code.ensure_loaded?(Ecto) do

defmodule FunWithFlags.Store.Persistent.Ecto do
  @moduledoc false

  alias FunWithFlags.{Config, Gate}
  alias FunWithFlags.Store.Persistent.Ecto.Record
  alias FunWithFlags.Store.Serializer.Ecto, as: Serializer

  import Ecto.Query

  @repo Config.ecto_repo()

  def worker_spec do
    nil
  end


  def get(flag_name) do
    name_string = to_string(flag_name)
    query = from(r in Record, where: r.flag_name == ^name_string)
    try do
      results = @repo.all(query)
      flag = deserialize(flag_name, results)
      {:ok, flag}
    rescue
      e in [Ecto.QueryError] -> {:error, e}
    end
  end


  def put(flag_name, gate = %Gate{type: :percent_of_time, for: target}) do
    name_string = to_string(flag_name)
    
    find_one_q = from(
      r in Record,
      where: r.flag_name == ^name_string,
      where: r.gate_type == "percent_of_time"
    )
    
    out = @repo.transaction fn() ->
      table_lock!()
      case @repo.one(find_one_q) do
        record = %Record{} ->
          changeset = Record.update_target(record, target)
          do_update(flag_name, changeset)
        nil ->
          changeset = Record.build(flag_name, gate)
          do_insert(flag_name, changeset)
      end
    end

    case out do
      {:ok, {:ok, result}} ->
        {:ok, result}
      {:error, _} = error ->
        error
    end
  end


  def put(flag_name, gate = %Gate{}) do
    changeset = Record.build(flag_name, gate)
    options = [
      on_conflict: [set: [enabled: gate.enabled]],
      conflict_target: [:flag_name, :gate_type, :target] # the unique index
    ]

    do_insert(flag_name, changeset, options)
  end



  def delete(flag_name, %Gate{type: :percent_of_time}) do
    name_string = to_string(flag_name)

    query = from(
      r in Record,
      where: r.flag_name == ^name_string
      and r.gate_type == "percent_of_time"
    )

    try do
      {_count, _} = @repo.delete_all(query)
      {:ok, flag} = get(flag_name)
      publish_change(flag_name)
      {:ok, flag}
    rescue
      e in [Ecto.QueryError] -> {:error, e}
    end
  end


  # Deletes one gate from the toggles table in the DB.
  # Deleting gates is idempotent and deleting unknown gates is safe.
  # A flag will continue to exist even though it has no gates.
  #
  def delete(flag_name, gate = %Gate{}) do
    name_string = to_string(flag_name)
    gate_type = to_string(gate.type)
    target    = Record.serialize_target(gate.for)

    query = from(
      r in Record,
      where: r.flag_name == ^name_string
      and r.gate_type == ^gate_type
      and r.target == ^target
    )

    try do
      {_count, _} = @repo.delete_all(query)
      {:ok, flag} = get(flag_name)
      publish_change(flag_name)
      {:ok, flag}
    rescue
      e in [Ecto.QueryError] -> {:error, e}
    end
  end


  # Deletes all of of this flags' gates from the toggles table, thus deleting
  # the entire flag.
  # Deleting flags is idempotent and deleting unknown flags is safe.
  # After the operation fetching the now-deleted flag will return the default
  # empty flag structure.
  #
  def delete(flag_name) do
    name_string = to_string(flag_name)

    query = from(
      r in Record,
      where: r.flag_name == ^name_string
    )

    try do
      {_count, _} = @repo.delete_all(query)
      {:ok, flag} = get(flag_name)
      publish_change(flag_name)
      {:ok, flag}
    rescue
      e in [Ecto.QueryError] -> {:error, e}
    end
  end


  def all_flags do
    flags =
      Record
      |> @repo.all()
      |> Enum.group_by(&(&1.flag_name))
      |> Enum.map(fn ({name, records}) -> deserialize(name, records) end)
    {:ok, flags}
  end


  def all_flag_names do
    query = from(r in Record, select: r.flag_name, distinct: true)
    strings = @repo.all(query)
    atoms = Enum.map(strings, &String.to_atom(&1))
    {:ok, atoms}
  end


  defp publish_change(flag_name) do
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end
  end

  defp deserialize(flag_name, records) do
    Serializer.deserialize_flag(flag_name, records)
  end


  defp table_lock! do
    Ecto.Adapters.SQL.query!(
      @repo,
      "LOCK TABLE fun_with_flags_toggles IN SHARE ROW EXCLUSIVE MODE;"
    )
  end


  defp do_insert(flag_name, changeset, options \\ []) do
    changeset
    |> @repo.insert(options)
    |> handle_write(flag_name)
  end


  defp do_update(flag_name, changeset, options \\ []) do
    changeset
    |> @repo.update(options)
    |> handle_write(flag_name)
  end


  defp handle_write(result, flag_name) do
    case result do
      {:ok, %Record{}} ->
        {:ok, flag} = get(flag_name)
        publish_change(flag_name)
        {:ok, flag}
      {:error, bad_changeset} ->
        {:error, bad_changeset.errors}
    end
  end

end

end # Code.ensure_loaded?
