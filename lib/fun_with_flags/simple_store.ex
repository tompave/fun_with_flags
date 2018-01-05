defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  defp persistence do
    FunWithFlags.Config.persistence_adapter()
  end


  def lookup(flag_name) do
    case persistence().get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  def put(flag_name, gate), do: persistence().put(flag_name, gate)
  def delete(flag_name, gate), do: persistence().delete(flag_name, gate)
  def delete(flag_name), do: persistence().delete(flag_name)
  def all_flags(), do: persistence().all_flags()
  def all_flag_names(), do: persistence().all_flag_names()
end
