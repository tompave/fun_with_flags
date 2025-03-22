defmodule FunWithFlags.Store do
  @moduledoc false

  require Logger
  alias FunWithFlags.Store.Cache
  alias FunWithFlags.{Config, Flag}

  import FunWithFlags.Config, only: [persistence_adapter: 0]

  @spec lookup(atom) :: {:ok, FunWithFlags.Flag.t}
  def lookup(flag_name) do
    case Cache.get(flag_name) do
      {:ok, flag} ->
        {:ok, flag}
      {:miss, reason, stale_value_or_nil} ->
        case persistence_adapter().get(flag_name) do
          {:ok, flag} ->
            emit_persistence_telemetry({:ok, nil}, :read, flag_name, nil)
            Cache.put(flag)
            {:ok, flag}
          err = {:error, _reason} ->
            emit_persistence_telemetry(err, :read, flag_name, nil)
            try_to_use_the_cached_value(reason, stale_value_or_nil, flag_name)
        end
    end
  end


  defp try_to_use_the_cached_value(:expired, value, flag_name) do
    Logger.warning "FunWithFlags: couldn't load flag '#{flag_name}' from storage, falling back to stale cached value from ETS"
    {:ok, value}
  end
  defp try_to_use_the_cached_value(_, _, flag_name) do
    raise "Can't load feature flag '#{flag_name}' from neither storage nor the cache"
  end


  @spec put(atom, FunWithFlags.Gate.t) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def put(flag_name, gate) do
    flag_name
    |> persistence_adapter().put(gate)
    |> emit_persistence_telemetry(:write, flag_name, gate)
    |> publish_change()
    |> cache_persistence_result()
  end


  @spec delete(atom, FunWithFlags.Gate.t) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name, gate) do
    flag_name
    |> persistence_adapter().delete(gate)
    |> emit_persistence_telemetry(:delete_gate, flag_name, gate)
    |> publish_change()
    |> cache_persistence_result()
  end


  @spec delete(atom) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name) do
    flag_name
    |> persistence_adapter().delete()
    |> emit_persistence_telemetry(:delete_flag, flag_name, nil)
    |> publish_change()
    |> cache_persistence_result()
  end


  @spec reload(atom) :: {:ok, FunWithFlags.Flag.t} | {:error, any()}
  def reload(flag_name) do
    Logger.debug fn -> "FunWithFlags: reloading cached flag '#{flag_name}' from storage " end
    flag_name
    |> persistence_adapter().get()
    |> emit_persistence_telemetry(:reload, flag_name, nil)
    |> cache_persistence_result()
  end


  @spec all_flags() :: {:ok, [FunWithFlags.Flag.t]} | {:error, any()}
  def all_flags do
    persistence_adapter().all_flags()
    |> emit_persistence_telemetry(:read_all_flags, nil, nil)
  end


  @spec all_flag_names() :: {:ok, [atom]} | {:error, any()}
  def all_flag_names do
    persistence_adapter().all_flag_names()
    |> emit_persistence_telemetry(:read_all_flag_names, nil, nil)
  end

  defp cache_persistence_result(result = {:ok, flag}) do
    Cache.put(flag)
    result
  end

  defp cache_persistence_result(result) do
    result
  end


  defp publish_change(result = {:ok, %Flag{name: flag_name}}) do
    if Config.change_notifications_enabled? do
      Config.notifications_adapter.publish_change(flag_name)
    end

    result
  end

  defp publish_change(result) do
    result
  end

  # Receive the flag name as an explicit parameter rather than pattern matching
  # it from the `{:ok, %Flag{}}`, because that tuple is only available on success,
  # and it's therefore not available when pipelining on an error.
  #
  defp emit_persistence_telemetry(result = {:ok, _}, event_name, flag_name, gate) do
    metadata = %{
      flag_name: flag_name,
      gate: gate,
    }

    FunWithFlags.Telemetry.persistence_event(event_name, metadata)
    result
  end

  defp emit_persistence_telemetry(result = {:error, reason}, event_name, flag_name, gate) do
    metadata = %{
      flag_name: flag_name,
      gate: gate,
      error: reason,
      original_event: event_name
    }

    FunWithFlags.Telemetry.persistence_event(:error, metadata)
    result
  end
end
