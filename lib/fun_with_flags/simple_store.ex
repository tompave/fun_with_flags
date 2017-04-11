defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  @persistence FunWithFlags.Store.Persistent.adapter


  def lookup(flag_name) do
    case @persistence.get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  defdelegate put(flag_name, gate), to: @persistence
  defdelegate delete(flag_name, gate), to: @persistence
  defdelegate delete(flag_name), to: @persistence
  defdelegate all_flags(), to: @persistence
  defdelegate all_flag_names(), to: @persistence
end
