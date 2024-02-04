defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.

  This module is the legacy interface from v1.x.

  See the [Usage](/fun_with_flags/readme.html#usage).
  """

  defmodule PrivateEntryPoint do
    @moduledoc false
    use FunWithFlags.EntryPoint

    @impl true
    def config do
      {:ok, []}
    end
  end

  require Logger
  @deprecation_msg "Using the FunWithFlags module directly is deprecated. (TODO link to docs)"

  def enabled?(flag_name, options \\ []) do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.enabled?(flag_name, options)
  end

  def enable(flag_name, options \\ []) do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.enable(flag_name, options)
  end

  def disable(flag_name, options \\ []) do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.disable(flag_name, options)
  end

  def clear(flag_name, options \\ []) do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.clear(flag_name, options)
  end

  def all_flag_names() do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.all_flag_names()
  end

  def all_flags() do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.all_flags()
  end

  def get_flag(flag_name) do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.get_flag(flag_name)
  end

  def compiled_store() do
    Logger.warning(@deprecation_msg)
    PrivateEntryPoint.compiled_store()
  end
end
