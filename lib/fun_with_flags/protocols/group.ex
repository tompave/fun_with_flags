defprotocol FunWithFlags.Group do
  @moduledoc """
  Implement this protocol to provide groups.

  Group gates are similar to actor gates, but they apply to a category of entities rather than specific ones. They can be toggled on or off for the _name of the group_ (as an atom) instead of a specific term.

  Group gates take precedence over boolean gates but are overridden by actor gates.

  The semantics to determine which entities belong to which groups are application specific.
  Entities could have an explicit list of groups they belong to, or the groups could be abstract and inferred from some other attribute. For example, an `:employee` group could comprise all `%User{}` structs with an email address matching the company domain, or an `:admin` group could be made of all users with `%User{admin: true}`.

  In order to be affected by a group gate, an entity should implement the `FunWithFlags.Group` protocol. The protocol automatically falls back to a default `Any` implementation, which states that any entity belongs to no group at all. This makes it possible to safely use "normal" actors when querying group gates, and to implement the protocol only for structs and types for which it matters.

  The protocol can be implemented for custom structs or literally any other type.


      defmodule MyApp.User do
        defstruct [:email, admin: false, groups: []]
      end

      defimpl FunWithFlags.Group, for: MyApp.User do
        def in?(%{email: email}, :employee),  do: Regex.match?(~r/@mycompany.com$/, email)
        def in?(%{admin: is_admin}, :admin),  do: !!is_admin
        def in?(%{groups: list}, group_name), do: group_name in list
      end

      elisabeth = %User{email: "elisabeth@mycompany.com", admin: true, groups: [:engineering, :product]}
      FunWithFlags.Group.in?(elisabeth, :employee)
      true
      FunWithFlags.Group.in?(elisabeth, :admin)
      true
      FunWithFlags.Group.in?(elisabeth, :engineering)
      true
      FunWithFlags.Group.in?(elisabeth, :marketing)
      false

      defimpl FunWithFlags.Group, for: Map do
        def in?(%{group: group_name}, group_name), do: true
        def in?(_, _), do: false
      end

      FunWithFlags.Group.in?(%{group: :dumb_tests}, :dumb_tests)
      true

  With the protocol implemented, actors can be used with the library functions:


      FunWithFlags.disable(:database_access)
      FunWithFlags.enable(:database_access, for_group: :engineering)
  """

  @fallback_to_any true

  @doc """
  Should return a boolean.

  The default implementation will always return `false` for
  any argument.

  ## Example

      iex> user = %{name: "bolo", group: "staff"}
      iex> FunWithFlags.Group.in?(data, "staff")
      true
      iex> FunWithFlags.Group.in?(data, "superusers")
      false
  """
  @spec in?(term, String.t() | atom) :: boolean
  def in?(item, group)
end

defimpl FunWithFlags.Group, for: Any do
  def in?(_, _), do: false
end
