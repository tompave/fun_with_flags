defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.

  This module provides the public interface to the library and its API is
  made of three simple methods to enable, disable and query feature flags.

  In their simplest form, flags can be toggled on and off globally.

  More advanced rules or "gates" are available, and they can be set and queried
  for any term that implements these protocols:

  * The `FunWithFlags.Actor` protocol can be
  implemented for types and structs that should have specific rules. For
  example, in web applications it's common to use a `%User{}` struct or
  equivalent as an actor, or perhaps the current country of the request.

  * The `FunWithFlags.Group` protocol can be
  implemented for types and structs that should belong to groups for which
  one wants to enable and disable some flags. For example, one could implement
  the protocol for a `%User{}` struct to identify administrators.


  See the [Usage](/fun_with_flags/readme.html#usage) notes for a more detailed
  explanation.
  """

  alias FunWithFlags.{Flag, Gate}

  @store FunWithFlags.Config.store_module

  @type options :: Keyword.t



  @doc """
  Checks if a flag is enabled.

  It can be invoked with just the flag name, as an atom,
  to check the general staus of a flag (i.e. the boolean gate).

  ## Options

  * `:for` - used to provide a term for which the flag could
  have a specific value. The passed term should implement the
  `Actor` or `Group` protocol, or both.

  ## Examples

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.

      iex> alias FunWithFlags.TestUser, as: User
      iex> harry = %User{id: 1, name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> FunWithFlags.disable(:elder_wand)
      iex> FunWithFlags.enable(:elder_wand, for_actor: harry)
      iex> FunWithFlags.enabled?(:elder_wand)
      false
      iex> FunWithFlags.enabled?(:elder_wand, for: harry)
      true
      iex> voldemort = %User{id: 7, name: "Tom Riddle", groups: ["wizards", "slytherin"]}
      iex> FunWithFlags.enabled?(:elder_wand, for: voldemort)
      false
      iex> filch = %User{id: 88, name: "Argus Filch", groups: ["staff"]}
      iex> FunWithFlags.enable(:magic_wands, for_group: "wizards")
      iex> FunWithFlags.enabled?(:magic_wands, for: harry)
      true
      iex> FunWithFlags.enabled?(:magic_wands, for: voldemort)
      true
      iex> FunWithFlags.enabled?(:magic_wands, for: filch)
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

  ## Options

  * `:for_actor` - used to enable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to enable the flag for a specific group only.
  The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)

  ## Examples

  ### Enable globally

      iex> FunWithFlags.enabled?(:super_shrink_ray)
      false
      iex> FunWithFlags.enable(:super_shrink_ray)
      {:ok, true}
      iex> FunWithFlags.enabled?(:super_shrink_ray)
      true

  ### Enable for an actor

      iex> FunWithFlags.disable(:warp_drive)
      {:ok, false}
      iex> FunWithFlags.enable(:warp_drive, for_actor: "Scotty")
      {:ok, true}
      iex> FunWithFlags.enabled?(:warp_drive)
      false
      iex> FunWithFlags.enabled?(:warp_drive, for: "Scotty")
      true

  ### Enable for a group

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.
      
      iex> alias FunWithFlags.TestUser, as: User
      iex> marty = %User{name: "Marty McFly", groups: ["students", "time_travelers"]}
      iex> doc = %User{name: "Emmet Brown", groups: ["scientists", "time_travelers"]}
      iex> buford = %User{name: "Buford Tannen", groups: ["gunmen", "bandits"]}
      iex> FunWithFlags.enable(:delorean, for_group: "time_travelers")
      {:ok, true}
      iex> FunWithFlags.enabled?(:delorean)
      false
      iex> FunWithFlags.enabled?(:delorean, for: buford)
      false
      iex> FunWithFlags.enabled?(:delorean, for: marty)
      true
      iex> FunWithFlags.enabled?(:delorean, for: doc)
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


  def enable(flag_name, [for_group: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, true)
    {:ok, _flag} = @store.put(flag_name, gate)
    {:ok, true}
  end


  def enable(flag_name, [for_percent_of_time: ratio]) when is_atom(flag_name) do
    gate = Gate.new(:percent_of_time, ratio)
    {:ok, _flag} = @store.put(flag_name, gate)
    {:ok, true}
  end



  @doc """
  Disables a feature flag.

  ## Options

  * `:for_actor` - used to disable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to disable the flag for a specific group only.
   The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)

  ## Examples

  ### Disable globally

      iex> FunWithFlags.enable(:random_koala_gifs)
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      true
      iex> FunWithFlags.disable(:random_koala_gifs)
      {:ok, false}
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      false


  ## Disable for an actor

      iex> FunWithFlags.enable(:spider_sense)
      {:ok, true}
      iex> villain = %{name: "Venom"}
      iex> FunWithFlags.disable(:spider_sense, for_actor: villain)
      {:ok, false}
      iex> FunWithFlags.enabled?(:spider_sense)
      true
      iex> FunWithFlags.enabled?(:spider_sense, for: villain)
      false

  ### Disable for a group

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.
      
      iex> alias FunWithFlags.TestUser, as: User
      iex> harry = %User{name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> dudley = %User{name: "Dudley Dursley", groups: ["muggles"]}
      iex> FunWithFlags.enable(:hogwarts)
      {:ok, true}
      iex> FunWithFlags.disable(:hogwarts, for_group: "muggles")
      {:ok, false}
      iex> FunWithFlags.enabled?(:hogwarts)
      true
      iex> FunWithFlags.enabled?(:hogwarts, for: harry)
      true
      iex> FunWithFlags.enabled?(:hogwarts, for: dudley)
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

  def disable(flag_name, [for_group: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, false)
    {:ok, _flag} = @store.put(flag_name, gate)
    {:ok, false}
  end



  @doc """
  Clears the data of a feature flag.

  Clears the data for an entire feature flag or for a specific
  Actor or Group gate. Clearing a boolean gate is not supported
  because a missing boolean gate is equivalent to a disabled boolean
  gate.

  Sometimes enabling or disabling a gate is not what you want, and you
  need to remove that gate's rules instead. For example, if you don't need
  anymore to explicitly enable or disable a flag for an actor, and the
  default state should be used instead, you'll want to cleare the gate.

  It's also possible to clear the entire flag, by not passing any option.

  ## Options

  * `:for_actor` - used to clear the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to clear the flag for a specific group only.
   The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)

  ## Examples

      iex> alias FunWithFlags.TestUser, as: User
      iex> harry = %User{id: 1, name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> hagrid = %User{id: 2, name: "Rubeus Hagrid", groups: ["wizards", "gamekeeper"]}
      iex> dudley = %User{id: 3, name: "Dudley Dursley", groups: ["muggles"]}
      iex> FunWithFlags.disable(:wands)
      iex> FunWithFlags.enable(:wands, for_group: "wizards")
      iex> FunWithFlags.disable(:wands, for_actor: hagrid)
      iex>
      iex> FunWithFlags.enabled?(:wands)
      false
      iex> FunWithFlags.enabled?(:wands, for: harry)
      true
      iex> FunWithFlags.enabled?(:wands, for: hagrid)
      false
      iex> FunWithFlags.enabled?(:wands, for: dudley)
      false
      iex>
      iex> FunWithFlags.clear(:wands, for_actor: hagrid)
      :ok
      iex> FunWithFlags.enabled?(:wands, for: hagrid)
      true
      iex>
      iex> FunWithFlags.clear(:wands)
      :ok
      iex> FunWithFlags.enabled?(:wands)
      false
      iex> FunWithFlags.enabled?(:wands, for: harry)
      false
      iex> FunWithFlags.enabled?(:wands, for: hagrid)
      false
      iex> FunWithFlags.enabled?(:wands, for: dudley)
      false


  """
  @spec clear(atom, options) :: :ok
  def clear(flag_name, options \\ [])

  def clear(flag_name, []) when is_atom(flag_name) do
    {:ok, _flag} = @store.delete(flag_name)
    :ok
  end

  def clear(flag_name, [for_actor: nil]) do
    clear(flag_name)
  end

  def clear(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, false) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  def clear(flag_name, [for_group: nil]) do
    clear(flag_name)
  end

  def clear(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, false) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  defp _clear_gate(flag_name, gate) do
    {:ok, _flag} = @store.delete(flag_name, gate)
    :ok
  end


  @doc """
  Returns a list of all flag names currently configured, as atoms.

  This can be useful for debugging or for display purposes,
  but it's not meant to be used at runtime. Undefined flags,
  for example, will be considered disabled.
  """
  @spec all_flag_names() :: {:ok, [atom]} | {:ok, []}
  defdelegate all_flag_names(), to: @store

  @doc """
  Returns a list of all the flags currently configured, as data structures.

  This function is provided for debugging and to build more complex
  functionality (e.g. it's used in the web GUI), but it is not meant to be
  used at runtime to check if a flag is enabled.

  To query the value of a flag, please use the `enabled?2` function instead.
  """
  @spec all_flags() :: {:ok, [FunWithFlags.Flag.t]} | {:ok, []}
  defdelegate all_flags(), to: @store


  defp verify(flag) do
    {:ok, Flag.enabled?(flag)}
  end
  defp verify(flag, [for: data]) do
    {:ok, Flag.enabled?(flag, for: data)}
  end
end
