defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.
  """

  @doc """
  Checks if a flag is enabled.

  ## Examples

      iex> FunWithFlags.enabled?(:foobar)
      false
      iex> FunWithFlags.enabled?(:querty)
      true
  """
  @spec enabled?(atom) :: boolean
  def enabled?(flag_name) when is_atom(flag_name) do
    false
  end



  @doc """
  Enables a feature flag.

  ## Examples

      iex> FunWithFlags.enabled?(:foobar)
      false
      iex> {:ok, true} = FunWithFlags.enable(:foobar)
      {:ok, true}
      iex> FunWithFlags.enabled?(:foobar)
      true

  """
  @spec enable(atom) :: {:ok, true}
  def enable(flag_name) when is_atom(flag_name) do
    {:ok, true}
  end



  @doc """
  Disables a feature flag.

  ## Examples

      iex> FunWithFlags.enabled?(:foobar)
      true
      iex> {:ok, false} = FunWithFlags.disable(:foobar)
      {:ok, false}
      iex> FunWithFlags.enabled?(:foobar)
      false

  """
  @spec disable(atom) :: {:ok, false}
  def disable(flag_name) when is_atom(flag_name) do
    {:ok, false}
  end

end
