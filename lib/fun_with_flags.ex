defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.

  This module is the legacy interface from v1.x.

  See the [Usage](/fun_with_flags/readme.html#usage).
  """

  use FunWithFlags.EntryPoint

  @impl true
  def config do
    {:ok, []}
  end
end
