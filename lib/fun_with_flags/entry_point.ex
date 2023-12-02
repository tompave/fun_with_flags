defmodule FunWithFlags.EntryPoint do
  @moduledoc """
  Defines an entry point to query feature flags.

  ## Example

      defmodule MyApp.Flags do
        use FunWithFlags.EntryPoint
      end

      MyApp.Flags.enabled?(:foo)

  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour FunWithFlags.EntryPoint

      # TODO: add what's currently in the top module.
    end
  end

  @doc """
  An entry point must define this callback to provide its configuration.

  This function is supposed to retrieve any runtime config (e.g. ENV vars) and
  return it as a keyword list.
  """
  @callback config() :: {:ok, Keyword.t()}
end
