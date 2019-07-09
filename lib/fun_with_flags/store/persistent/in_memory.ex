defmodule FunWithFlags.Store.Persistent.InMemory do
  alias FunWithFlags.{Config, Gate, Flag, Store.Persistent.Ecto.Record}

  def worker_spec do
    import Supervisor.Spec, only: [worker: 3]

    worker(__MODULE__, [], restart: :permanent)
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    {:ok, []}
  end

  def get(flag_name) do
    GenServer.call(__MODULE__, {:get, flag_name})
  end

  def put(flag_name, gate) do
    GenServer.call(__MODULE__, {:put, flag_name, gate})
  end

  def delete(flag_name, %Gate{} = gate) do
    GenServer.call(__MODULE__, {:delete, flag_name, gate})
  end

  def delete(flag_name) do
    GenServer.call(__MODULE__, {:delete, flag_name})
  end

  def all_flags do
    GenServer.call(__MODULE__, :all_flags)
  end

  def all_flag_names do
    GenServer.call(__MODULE__, :all_flag_names)
  end

  def handle_call({:get, flag_name}, _from, gates) do
    {:reply, do_get(flag_name, gates), gates}
  end

  def handle_call({:put, flag_name, gate = %Gate{type: type}}, _from, gates) do
    record = %Record{
      flag_name: to_string(flag_name),
      gate_type: to_string(type),
      target: Record.serialize_target(gate.for),
      enabled: gate.enabled
    }

    index =
      Enum.find_index(
        gates,
        &(&1.flag_name == to_string(flag_name) and
            &1.gate_type == "percentage")
      )

    new_gates =
      case index do
        nil ->
          [record | gates] |> Enum.uniq()

        index ->
          List.replace_at(gates, index, record)
      end

    publish_change(flag_name)

    {:reply, do_get(flag_name, new_gates), new_gates}
  end

  def handle_call({:delete, flag_name, gate}, _from, gates) do
    new_gates =
      gates
      |> Enum.reject(
        &(&1.flag_name == to_string(flag_name) and
            &1.gate_type == to_string(gate.type) and
            &1.target == Record.serialize_target(gate.for))
      )

    publish_change(flag_name)

    {:reply, do_get(flag_name, new_gates), new_gates}
  end

  def handle_call({:delete, flag_name}, _from, gates) do
    new_gates =
      gates
      |> Enum.reject(&(&1.flag_name == to_string(flag_name)))

    publish_change(flag_name)

    {:reply, do_get(flag_name, new_gates), new_gates}
  end

  def handle_call(:all_flags, _from, gates) do
    flags =
      gates
      |> Enum.group_by(& &1.flag_name)
      |> Enum.map(fn {name, records} -> Flag.new(to_atom(name), records) end)

    {:reply, {:ok, flags}, gates}
  end

  def handle_call(:all_flag_names, _from, gates) do
    names =
      gates
      |> Enum.map(&String.to_atom(&1.flag_name))
      |> Enum.uniq()

    {:reply, {:ok, names}, gates}
  end

  defp do_get(flag_name, gates) do
    name_string = to_string(flag_name)

    matching_gates =
      gates
      |> Enum.filter(&(&1.flag_name == name_string))
      |> Enum.map(&do_deserialize_gate/1)

    {:ok, Flag.new(to_atom(flag_name), matching_gates)}
  end

  defp do_deserialize_gate(%Record{gate_type: "boolean", enabled: enabled}) do
    %Gate{type: :boolean, for: nil, enabled: enabled}
  end

  defp do_deserialize_gate(%Record{
          gate_type: "actor",
          enabled: enabled,
          target: target
        }) do
    %Gate{type: :actor, for: target, enabled: enabled}
  end

  defp do_deserialize_gate(%Record{
          gate_type: "group",
          enabled: enabled,
          target: target
        }) do
    %Gate{type: :group, for: target, enabled: enabled}
  end

  defp publish_change(flag_name) do
    if Config.change_notifications_enabled?() do
      Config.notifications_adapter().publish_change(flag_name)
    end
  end

  def to_atom(atm) when is_atom(atm), do: atm
  def to_atom(str) when is_binary(str), do: String.to_atom(str)
end
