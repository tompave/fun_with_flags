defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.
  """

  @doc """
  Checks if a flag is enabled.

  ## Examples

      iex> FunWithFlags.enabled?(:new_homepage)
      false
  """
  @spec enabled?(atom) :: boolean
  def enabled?(flag_name) when is_atom(flag_name) do
    case :ets.lookup(:fun_with_flags, flag_name) do
      [{^flag_name, value}] -> value
      _ -> false
    end
  end



  @doc """
  Enables a feature flag.

  ## Examples

      iex> FunWithFlags.enabled?(:super_shrink_ray)
      false
      iex> {:ok, true} = FunWithFlags.enable(:super_shrink_ray)
      {:ok, true}
      iex> FunWithFlags.enabled?(:super_shrink_ray)
      true

  """
  @spec enable(atom) :: {:ok, true}
  def enable(flag_name) when is_atom(flag_name) do
    case :ets.insert(:fun_with_flags, {flag_name, true}) do
      true -> {:ok, true}
      _ -> {:error, "couldn't enable the flag"}
    end
  end



  @doc """
  Disables a feature flag.

  ## Examples

      iex> FunWithFlags.enable(:random_koala_gifs)
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      true
      iex> {:ok, false} = FunWithFlags.disable(:random_koala_gifs)
      {:ok, false}
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      false

  """
  @spec disable(atom) :: {:ok, false}
  def disable(flag_name) when is_atom(flag_name) do
    case :ets.insert(:fun_with_flags, {flag_name, false}) do
      true -> {:ok, false}
      _ -> {:error, "couldn't disable the flag"}
    end
  end

end
