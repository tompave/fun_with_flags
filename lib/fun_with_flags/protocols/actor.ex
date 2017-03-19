defprotocol FunWithFlags.Actor do
  @moduledoc ~S"""
  Implement this protocol to provide actors.


  Actor gates allows you to enable or disable a flag for one or more entities.
  For example, in web applications it's common to use a `%User{}` struct or
  equivalent as an actor, or perhaps the data used to represent the current
  country for an HTTP request.
  This can be useful to showcase a work-in-progress feature to someone, to
  gradually rollout a functionality by country, or to dynamically disable some
  features in some contexts (e.g. a deploy introduces a critical error that
  only happens in one specific country).

  Actor gates take precendence over the others, both when they're enabled and
  when they're disabled. They can be considered as toggle overrides.


  In order to be used as an actor, an entity must implement
  the `FunWithFlags.Actor` protocol. This is a plain Elixir protocol and can
  be implemented for custom structs or literally any other type.


  ## Examples

  This protocol is typically implemented for some application structure.
  
      defmodule MyApp.User do
        defstruct [:id, :name]
      end

      defimpl FunWithFlags.Actor, for: MyApp.User do
        def id(user) do
          "user:#{user.id}"
        end
      end


      bruce = %User{id: 1, name: "Bruce"}
      FunWithFlags.enable(:batmobile, for_actor: bruce)


  but it can also be implemented for the builtin types:


      defimpl FunWithFlags.Actor, for: Map do
        def id(%{actor_id: actor_id}) do
          "map:#{actor_id}"
        end

        def id(map) do
          map
          |> inspect()
          |> (&:crypto.hash(:md5, &1)).()
          |> Base.encode16
          |> (&"map:#{&1}").()
        end
      end


      defimpl FunWithFlags.Actor, for: BitString do
        def id(str) do
          "string:#{str}"
        end
      end


      FunWithFlags.disable(:foobar, for_actor: %{actor_id: "just a map"})
      FunWithFlags.enable(:foobar, for_actor: "just a string")


  Actor identifiers must be globally unique binaries. A common technique to
  support multiple kinds of actors is to namespace the IDs:


      defimpl FunWithFlags.Actor, for: MyApp.User do
        def id(user) do
          "user:#{user.id}"
        end
      end

      defimpl FunWithFlags.Actor, for: MyApp.Country do
        def id(country) do
          "country:#{country.iso3166}"
        end
      end
  """


  @doc """
  Should return a globally unique binary.

  ## Example

      iex> FunWithFlags.Actor.id(%FunWithFlags.TestUser{id: 313})
      "user:313"

  """
  @spec id(term) :: binary
  def id(actor)
end
