defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  alias FunWithFlags.Config

  def lookup(flag_name) do
    case Config.persistence_adapter().get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  defdelegate put(flag_name, gate), to: Config.persistence_adapter()
  defdelegate delete(flag_name, gate), to: Config.persistence_adapter()
  defdelegate delete(flag_name), to: Config.persistence_adapter()
  defdelegate all_flags(), to: Config.persistence_adapter()
  defdelegate all_flag_names(), to: Config.persistence_adapter()

end
