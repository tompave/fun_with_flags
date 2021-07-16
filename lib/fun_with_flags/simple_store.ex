defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  import FunWithFlags.Config, only: [persistence_adapter: 0]

  def lookup(flag_name) do
    case persistence_adapter().get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  def put(flag_name, gate) do
    persistence_adapter().put(flag_name, gate)
  end

  def delete(flag_name, gate) do
    persistence_adapter().delete(flag_name, gate)
  end

  def delete(flag_name) do
    persistence_adapter().delete(flag_name)
  end

  def all_flags do
    persistence_adapter().all_flags()
  end

  def all_flag_names do
    persistence_adapter().all_flag_names()
  end
end
