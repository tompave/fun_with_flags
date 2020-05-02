defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  import FunWithFlags.Config, only: [persistence_adapter: 0]

  def lookup(flag_name) do
    case persistence_adapter().get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  defdelegate put(flag_name, gate), to: persistence_adapter()
  defdelegate delete(flag_name, gate), to: persistence_adapter()
  defdelegate delete(flag_name), to: persistence_adapter()
  defdelegate all_flags(), to: persistence_adapter()
  defdelegate all_flag_names(), to: persistence_adapter()

end
