defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.

  See the [Usage](file:///Users/Tom/Documents/source/elixir/fun_with_flags/doc/readme.html#usage)
  notes for a more detailed explanation, and the
  [Actor protocol](file:///Users/Tom/Documents/source/elixir/fun_with_flags/doc/FunWithFlags.Actor.html)
  documentation for more examples on how to work with Actor toggles.
  """

  alias FunWithFlags.{Flag, Gate}

  @store FunWithFlags.Config.store_module

  @type options :: Keyword.t



  @doc """
  Checks if a flag is enabled.

  It can be invoked with just the flag name, as an atom,
  to check the general staus of a flag (i.e. the boolean gate).

  ## Examples

      iex> FunWithFlags.enabled?(:new_homepage)
      false

  ## Options

    * `:for` - used to specify a term for which the flag could
    have a specific rule.

  ## Examples

      iex> wizard = %{id: 42, name: "Harry Potter"}
      iex> FunWithFlags.disable(:elder_wand)
      iex> FunWithFlags.enable(:elder_wand, for_actor: wizard)
      iex> FunWithFlags.enabled?(:elder_wand)
      false
      iex> FunWithFlags.enabled?(:elder_wand, for: wizard)
      true
      iex> other_wizard = %{id: 7, name: "Tom Riddle"}
      iex> FunWithFlags.enabled?(:elder_wand, for: other_wizard)
      false

  """
  @spec enabled?(atom, options) :: boolean

  def enabled?(flag_name, options \\ [])


  def enabled?(flag_name, []) when is_atom(flag_name) do
    case @store.lookup(flag_name) do
      {:ok, flag} -> Flag.enabled?(flag)
      _           -> false
    end
  end

  def enabled?(flag_name, [for: nil]) do
    enabled?(flag_name)
  end

  def enabled?(flag_name, [for: item]) when is_atom(flag_name) do
    case @store.lookup(flag_name) do
      {:ok, flag} -> Flag.enabled?(flag, for: item)
      _           -> false
    end
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

  ## Options

    * `:for_actor` - used to enable the flag for a specific
    term only. This can be anything.

  ## Examples

      iex> FunWithFlags.disable(:warp_drive)
      {:ok, false}
      iex> FunWithFlags.enable(:warp_drive, for_actor: "Scotty")
      {:ok, true}
      iex> FunWithFlags.enabled?(:warp_drive)
      false
      iex> FunWithFlags.enabled?(:warp_drive, for: "Scotty")
      true

  """
  @spec enable(atom, options) :: {:ok, true}
  def enable(flag_name, options \\ [])

  def enable(flag_name, []) when is_atom(flag_name) do
    {:ok, flag} = @store.put(flag_name, Gate.new(:boolean, true))
    verify(flag)
  end

  def enable(flag_name, [for_actor: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, true)
    {:ok, flag} = @store.put(flag_name, gate)
    verify(flag, for: actor)
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

  ## Options

    * `:for_actor` - used to disable the flag for a specific
    term only. This can be anything.

  ## Examples

      iex> FunWithFlags.enable(:spider_sense)
      {:ok, true}
      iex> villain = %{name: "Venom"}
      iex> FunWithFlags.disable(:spider_sense, for_actor: villain)
      {:ok, false}
      iex> FunWithFlags.enabled?(:spider_sense)
      true
      iex> FunWithFlags.enabled?(:spider_sense, for: villain)
      false

  """
  @spec disable(atom, options) :: {:ok, false}
  def disable(flag_name, options \\ [])

  def disable(flag_name, []) when is_atom(flag_name) do
    {:ok, flag} = @store.put(flag_name, Gate.new(:boolean, false))
    verify(flag)
  end

  def disable(flag_name, [for_actor: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, false)
    {:ok, flag} = @store.put(flag_name, gate)
    verify(flag, for: actor)
  end


  defp verify(flag) do
    {:ok, Flag.enabled?(flag)}
  end
  defp verify(flag, [for: data]) do
    {:ok, Flag.enabled?(flag, for: data)}
  end
end
