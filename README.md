# FunWithFlags

[![Build Status](https://travis-ci.org/tompave/fun_with_flags.svg?branch=master)](https://travis-ci.org/tompave/fun_with_flags)
[![Hex.pm](https://img.shields.io/hexpm/v/fun_with_flags.svg)](https://hex.pm/packages/fun_with_flags)
[![hexdocs.pm](https://img.shields.io/badge/docs-0.7.1-brightgreen.svg)](https://hexdocs.pm/fun_with_flags/)

FunWithFlags, the Elixir feature flag library.

This readme refers to the `master` branch. For the latest version released on Hex, please check [the readme published with the docs](https://hexdocs.pm/fun_with_flags/readme.html).

---

FunWithFlags is an OTP application that provides a 2-level storage to save and retrieve feature flags, an Elixir API to toggle and query them, and a [web dashboard](#web-dashboard) as control panel.

It stores flag information in Redis for persistence and syncronization across different nodes, but it also maintains a local cache in an ETS table for fast lookups. When flags are added or toggled on a node, the other nodes are notified via PubSub and reload their local ETS caches.

## Content

* [What's a feature flag](#whats-a-feature-flag)
* [Usage](#usage)
  - [Boolean Gate](#boolean-gate)
  - [Actor Gate](#actor-gate)
  - [Group Gate](#group-gate)
  - [Clearing a feature flag's rules](#clearing-a-feature-flags-rules)
* [Web Dashboard](#web-dashboard)
* [Origin](#origin)
* [So, caching, huh?](#so-caching-huh)
* [To Do](#to-do)
* [Configuration](#configuration)
  - [Persistence Adapters](#persistence-adapters)
  - [PubSub Adapters](#pubsub-adapters)
* [Installation](#installation)
* [Testing](#testing)

## What's a feature flag?

Feature flags, or feature toggles, are boolean values associated to a name. They should be used to control whether some application feature is enabled or disabled, and they are meant to be modified at runtime while an application is running. This is usually done by the people who control the application.

In their simplest form, flags can be toggled on and off globally. More advanced rules or "gates" allow a fine grained control over their status. For example, it's possible to toggle a flag on and off for specific entities or for groups.

The goal is to have more granular and precise control over what is made available to which users, and when.
A common use case, in web applications, is to enable a functionality without the need to deploy or restart the server, or to enable it only for internal users to test it before rolling it out to everyone. Another scenario is the ability to quickly disable a functionality if it's causing problems.
They can also be used to implement a simple authorization system, for example to an admin area.


## Usage

FunWithFlags has a simple API to query and toggle feature flags. Most of the time, you'll call `FunWithFlags.enabled?/2` with the name of the flag and optional arguments.

Different kinds of toggle gates are supported:

* **Boolean**: globally on and off.
* **Actors**: on or off for specific structs or data. The `FunWithFlags.Actor` protocol can be
implemented for types and structs that should have specific rules. For example, in web applications it's common to use a `%User{}` struct or equivalent as an actor, or perhaps the current country of the request.
* **Groups**: or or off for structs or data that belong to a category or satisfy a condition. The `FunWithFlags.Group` protocol can be implemented for types and structs that belong to groups for which a feature flag can be enabled or disabled. For example, one could implement the protocol for a `%User{}` struct to identify administrators.

The priority order is from most to least specific: `Actors > Groups > Boolean`, and it applies to both enabled and disabled gates. For example, a disabled group gate takes precendence over an enabled boolean (global) gate for the entities in the group, and a further enabled actor gate overrides the disabled group gate for a specific entity. When an entity belongs to multiple groups with conflicting toggle status, the disabled group gates have precedence over the enabled ones.

### Boolean Gate

The boolean gate is the simplest one. It's either enabled or disabled, globally. It's also the gate with the lowest priority. If a flag is undefined, it defaults to be globally disabled.

```elixir
FunWithFlags.enabled?(:cool_new_feature)
false

{:ok, true} = FunWithFlags.enable(:cool_new_feature)

FunWithFlags.enabled?(:cool_new_feature)
true

{:ok, false} = FunWithFlags.disable(:cool_new_feature)

FunWithFlags.enabled?(:cool_new_feature)
false
```

### Actor Gate

This allows you to enable or disable a flag for one or more entities. For example, in web applications it's common to use a `%User{}` struct or equivalent as an actor, or perhaps the data used to represent the current country for an HTTP request. This can be useful to showcase a work-in-progress feature to someone, to gradually rollout a functionality by country, or to dynamically disable some features in some contexts.

Actor gates take precendence over the others, both when they're enabled and when they're disabled. They can be considered as toggle overrides.

In order to be used as an actor, an entity must implement the `FunWithFlags.Actor` protocol. This can be implemented for custom structs or literally any other type.


```elixir
defmodule MyApp.User do
  defstruct [:id, :name]
end

defimpl FunWithFlags.Actor, for: MyApp.User do
  def id(%{id: id}) do
    "user:#{id}"
  end
end

bruce = %User{id: 1, name: "Bruce"}
alfred = %User{id: 2, name: "Alfred"}

FunWithFlags.Actor.id(bruce)
"user:1"
FunWithFlags.Actor.id(alfred)
"user:2"

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

FunWithFlags.Actor.id(%{actor_id: "bar"})
"map:bar"
FunWithFlags.Actor.id(%{foo: "bar"})
"map:E0BB5BA6873E3AC34B0B6928190C1F2B"
```

With the protocol implemented, actors can be used with the library functions:

```elixir
{:ok, true} = FunWithFlags.enable(:restful_nights)
{:ok, false} = FunWithFlags.disable(:restful_nights, for_actor: bruce)
{:ok, true} = FunWithFlags.enable(:batmobile, for_actor: bruce)

FunWithFlags.enabled?(:restful_nights)
true
FunWithFlags.enabled?(:batmobile)
false

FunWithFlags.enabled?(:restful_nights, for: alfred)
true
FunWithFlags.enabled?(:batmobile, for: alfred)
false

FunWithFlags.enabled?(:restful_nights, for: bruce)
false
FunWithFlags.enabled?(:batmobile, for: bruce)
true
```

Actor identifiers must be globally unique binaries. Since supporting multiple kinds of actors is a common requirement, all the examples use the common technique of namespacing the IDs:

```elixir
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
```

### Group Gate

Group gates are similar to actor gates, but they apply to a category of entities rather than specific ones. They can be toggled on or off for the _name of the group_ (as an atom) instead of a specific term.

Group gates take precendence over boolean gates but are overridden by actor gates.

The semantics to determine which entities belong to which groups are application specific.
Entities could have an explicit list of groups they belong to, or the groups could be abstract and inferred from some other attribute. For example, an `:employee` group could comprise all `%User{}` structs with an email address matching the company domain, or an `:admin` group could be made of all users with `%User{admin: true}`.

In order to be affected by a group gate, an entity should implement the `FunWithFlags.Group` protocol. The protocol automatically falls back to a default `Any` implementation, which states that any entity belongs to no group at all. This makes it possible to safely use "normal" actors when querying group gates, and to implement the protocol only for structs and types for which it matters.

The protocol can be implemented for custom structs or literally any other type.


```elixir
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
```

With the protocol implemented, actors can be used with the library functions:

```elixir
FunWithFlags.disable(:database_access)
FunWithFlags.enable(:database_access, for_group: :engineering)

FunWithFlags.enabled?(:database_access)
false
FunWithFlags.enabled?(:database_access, for: elisabeth)
true
```

### Clearing a feature flag's rules

Sometimes enabling or disabling a gate is not what you want, and removing that gate's rules would be more correct. For example, if you don't need anymore to explicitly enable or disable a flag for an actor or for a group, and the default state should be used instead, clearing the gate is the right choice.

More examples:

```elixir
alias FunWithFlags.TestUser, as: User
harry = %User{id: 1, name: "Harry Potter", groups: [:wizards, :gryffindor]}
hagrid = %User{id: 2, name: "Rubeus Hagrid", groups: [:wizards, :gamekeeper]}
dudley = %User{id: 3, name: "Dudley Dursley", groups: [:muggles]}
FunWithFlags.disable(:wands)
FunWithFlags.enable(:wands, for_group: :wizards)
FunWithFlags.disable(:wands, for_actor: hagrid)

FunWithFlags.enabled?(:wands)
false
FunWithFlags.enabled?(:wands, for: harry)
true
FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: dudley)
false

FunWithFlags.clear(:wands, for_actor: hagrid)
FunWithFlags.enabled?(:wands, for: hagrid)
true

FunWithFlags.clear(:wands, for_group: :wizards)
FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: harry)
false
```

It's also possible to clear an entire flag.

```elixir
FunWithFlags.clear(:wands)
FunWithFlags.enabled?(:wands)
false
FunWithFlags.enabled?(:wands, for: harry)
false
FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: dudley)
false
```

## Web Dashboard

An optional extension of this library is [`FunWithFlags.UI`](https://github.com/tompave/fun_with_flags_ui), a web graphical control panel. It's a Plug, so it can be embedded in a host Phoenix or Plug application or served standalone.


## Origin

This library is heavily inspired by the [flipper Ruby gem](https://github.com/jnunemaker/flipper).

Having used Flipper in production at scale, this project aims to improve in two main areas:

* Minimize the load on Redis: feature flags are not toggled _that_ often, and there is no need to query Redis for each check.
* Be more reliable: it should keep working with the latest cached values even if Redis becomes unavailable, although with the risk of nodes getting out of sync.

Just as Elixir and Phoenix are meant to scale better than Ruby on Rails with high levels of traffic and concurrency, FunWithFlags should aim to be more scalable and reliable than Flipper.

## So, caching, huh?

> There are only two hard things in Computer Science: cache invalidation and naming things.
> 
> -- Phil Karlton

The reason to add an ETS cache is that, most of the time, feature flags can be considered static values. Doing a round-trip to Redis is expensive in terms of time and in terms of resources, expecially if multiple flags must be checked during a single web request. In the worst cases, the load on Redis can become a cause of concern, a performance bottleneck or the source of a system failure.

Often the solution is to memoize the flag values _in the context of the web request_, but the apprach can be extended to the scope of the entire server.

Of course, caching adds a different kind of complexity and there are some pros and cons. When a flag is created or updated the ETS cache on the local node is updated immediately, and the main problem is syncronizing the flag data across the other application nodes that should share the same view of the world.

For example, of we have two or more nodes running the application, and on one of them an admin user updates a flag that the others have already cached, or creates a flag that the others have already looked up (and cached as "disabled"), then the other nodes must  be notified of the changes.

FunWithFlags uses three mechanisms to deal with the problem:

1. Use PubSub to emit change notifications. All nodes subscribe to the same channel and reload flags in the ETS cache when required.
2. If that fails, the cache has a configurable TTL. Reading from redis every few minutes is still better than doing so 30k times per second.
3. If that doesn't work, it's possible to disable the cache and just read from Redis all the time. That's what Flipper does.


## To Do

* Add some optional randomness to the TTL, so that Redis doesn't get hammered at constant intervals after a server restart.
* % of actors gate.
* % of time gate.
* Alternative persistence adapter (Ecto or Postgrex).


## Configuration

The library can be configured in host applications through Mix and the `config.exs` file. This example shows the default values:

```elixir
config :fun_with_flags, :cache,
  enabled: true,
  ttl: 900 # in seconds

# the Redis options will be forwarded to Redix
config :fun_with_flags, :redis,
  host: 'localhost',
  port: 6379,
  database: 0

# a URL string can be used instead
config :fun_with_flags, :redis, "redis://locahost:6379/0"

# only the Redis adapter is available at the moment. No need to set this.
config :fun_with_flags, :persistence,
  [adapter: FunWithFlags.Store.Persistent.Redis]

# this can be disabled if you are running on a single node and don't need to
# sync different ETS caches. It won't have any effect if the cache is disabled.
config :fun_with_flags, :cache_bust_notifications,
  [enabled: true, adapter: FunWithFlags.Notifications.Redis]
```

### Persistence Adapters

It's possible to configure different persistence adapters. The default is the provided Redis module and there is no need to set it explicitly. No other persistent adapters are provided at the moment, but the internal API allows the development of 3rd party adapters.

To configure them:

```elixir
config :fun_with_flags, :persistence, [adapter: MyCustomPersistenceModule]
```


### PubSub Adapters

The library comes with two PubSub adapters: [`Redix.PubSub`](https://hex.pm/packages/redix_pubsub) and [`Phoenix.PubSub`](https://hex.pm/packages/phoenix_pubsub).

The Redis adapter is the default and it connects directly to the Redis instance used for persisting the flag data.

The Phoenix PubSub adapter uses the high level API of `Phoenix.PubSub`, which means that under the hood it could use either its PG2 or Redis adapters, and this library doesn't need to know. It's provided as a convenient way to leverage distributed Erlang when using FunWithFlags in a Phoenix application, although it can be used independently (without the rest of the Phoenix framework) to add PubSub to Elixir apps running on Erlang clusters.  
FunWithFlags expects the `Phoenix.PubSub` process to be started by the host application, and in order to use this adapter the client (name or PID) must be provided in the configuration.

For example, in Phoenix it would be:

```elixir
config :my_app, MyApp.Web.Endpoint,
  pubsub: [name: MyApp.PubSub, adapter: Phoenix.PubSub.PG2]

config :fun_with_flags, :cache_bust_notifications,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: MyApp.PubSub
```

Or, without Phoenix:

```elixir
# possibly in the application's supervision tree
{:ok, _pid} = Phoenix.PubSub.PG2.start_link(:my_pubsub_process_name)

# config/config.exs
config :fun_with_flags, :cache_bust_notifications,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: :my_pubsub_process_name
```

## Installation

The package can be installed by adding `fun_with_flags` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fun_with_flags, "~> 0.7.1"}]
end
```

Since it depends on Elixir `1.4`, there is [no need to explicitly declare the application](https://github.com/elixir-lang/elixir/blob/v1.4/CHANGELOG.md#application-inference).

## Testing

This library depends on Redis and you'll need it installed on your system in order to run the tests. A test run will create a few keys in the [Redis db number 5](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_utils.ex#L2) and then remove them, but it's safer to start Redis in a directory where there is no `dump.rdb` file you care about to avoid issues.

Start Redis with:
```shell
$ redis-server
```

Then:
```
$ mix test.all
```

The `test.all` task will first run the default `mix test` task, then re-run the integration tests only, with the ETS cache disabled.
