defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.
  """

  alias FunWithFlags.Store

  @doc """
  Checks if a flag is enabled.

  ## Examples

      iex> FunWithFlags.enabled?(:new_homepage)
      false
  """
  @spec enabled?(atom) :: boolean
  def enabled?(flag_name) when is_atom(flag_name) do
    Store.lookup(flag_name)
  end



  @doc """
  Enables a feature flag.

  ## Examples

      iex> FunWithFlags.enabled?(:super_shrink_ray)
      false
      iex> FunWithFlags.enable(:super_shrink_ray)
      {:ok, true}
      iex> FunWithFlags.enabled?(:super_shrink_ray)
      true

  """
  @spec enable(atom) :: {:ok, true}
  def enable(flag_name) when is_atom(flag_name) do
    Store.put(flag_name, true)
  end



  @doc """
  Disables a feature flag.

  ## Examples

      iex> FunWithFlags.enable(:random_koala_gifs)
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      true
      iex> FunWithFlags.disable(:random_koala_gifs)
      {:ok, false}
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      false

  """
  @spec disable(atom) :: {:ok, false}
  def disable(flag_name) when is_atom(flag_name) do
    Store.put(flag_name, false)
  end

end
