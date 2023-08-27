# FunWithFlags

[![Mix Tests](https://github.com/tompave/fun_with_flags/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/tompave/fun_with_flags/actions/workflows/test.yml?query=branch%3Amaster)
[![Code Quality](https://github.com/tompave/fun_with_flags/actions/workflows/quality.yml/badge.svg?branch=master)](https://github.com/tompave/fun_with_flags/actions/workflows/quality.yml?query=branch%3Amaster)  
[![Hex.pm](https://img.shields.io/hexpm/v/fun_with_flags.svg)](https://hex.pm/packages/fun_with_flags)
[![hexdocs.pm](https://img.shields.io/badge/docs-1.11.0-brightgreen.svg)](https://hexdocs.pm/fun_with_flags/1.11.0/FunWithFlags.html)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/fun_with_flags)](https://hex.pm/packages/fun_with_flags)
[![License](https://img.shields.io/hexpm/l/fun_with_flags.svg)](https://github.com/tompave/fun_with_flags/blob/master/LICENSE.txt)
[![ElixirWeekly](https://img.shields.io/badge/featured-ElixirWeekly-8e5ab5.svg)](https://elixirweekly.net/issues/43)
[![ElixirCasts](https://img.shields.io/badge/featured-ElixirCasts-ff931e.svg)](https://elixircasts.io/feature-flags)

FunWithFlags, the Elixir feature flag library.

If you're reading this on the [GitHub repo](https://github.com/tompave/fun_with_flags), keep in mind that this readme refers to the `master` branch. For the latest version released on Hex, please check [the readme published with the docs](https://hexdocs.pm/fun_with_flags/readme.html).

---

FunWithFlags is an OTP application that provides a 2-level storage to save and retrieve feature flags, an Elixir API to toggle and query them, and a [web dashboard](#web-dashboard) as control panel.

It stores flag information in Redis or a relational DB (PostgreSQL, MySQL, or SQLite - with Ecto) for persistence and synchronization across different nodes, but it also maintains a local cache in an ETS table for fast lookups. When flags are added or toggled on a node, the other nodes are notified via PubSub and reload their local ETS caches.

## Content

* [What's a Feature Flag](#whats-a-feature-flag)
* [Usage](#usage)
  - [Gate Priority and Interactions](#gate-priority-and-interactions)
  - [Boolean Gate](#boolean-gate)
  - [Actor Gate](#actor-gate)
  - [Group Gate](#group-gate)
  - [Percentage of Time Gate](#percentage-of-time-gate)
  - [Percentage of Actors Gate](#percentage-of-actors-gate)
  - [Clearing a Feature Flag's Rules](#clearing-a-feature-flags-rules)
* [Web Dashboard](#web-dashboard)
* [Origin](#origin)
* [So, caching, huh?](#so-caching-huh)
* [To Do](#to-do)
* [Installation](#installation)
* [Configuration](#configuration)
  - [Persistence Adapters](#persistence-adapters)
    - [Ecto Multi-tenancy](#ecto-multi-tenancy)
    - [Ecto Custom Primary Key Types](#ecto-custom-primary-key-types)
  - [PubSub Adapters](#pubsub-adapters)
* [Extensibility](#extensibility)
  - [Custom Persistence Adapters](#custom-persistence-adapters)
* [Application Start Behaviour](#application-start-behaviour)
* [Testing](#testing)
* [Development](#development)
  - [Working with PubSub Locally](#working-with-pubsub-locally)

## What's a Feature Flag?

Feature flags, or feature toggles, are boolean values associated to a name. They should be used to control whether some application feature is enabled or disabled, and they are meant to be modified at runtime while an application is running. This is usually done by the people who control the application.

In their simplest form, flags can be toggled on and off globally. More advanced rules or "gates" allow a fine grained control over their status. For example, it's possible to toggle a flag on and off for specific entities or for groups.

The goal is to have more granular and precise control over what is made available to which users, and when.
A common use case, in web applications, is to enable a functionality without the need to deploy or restart the server, or to enable it only for internal users to test it before rolling it out to everyone. Another scenario is the ability to quickly disable a functionality if it's causing problems.
They can also be used to implement a simple authorization system, for example to an admin area.


## Usage

FunWithFlags has a simple API to query and toggle feature flags. Most of the time, you'll call `FunWithFlags.enabled?/2` with the name of the flag and optional arguments.

Different kinds of toggle gates are supported:

* **Boolean**: globally on and off.
* **Actors**: on or off for specific structs or data. The `FunWithFlags.Actor` protocol can be implemented for types and structs that should have specific rules. For example, in web applications it's common to use a `%User{}` struct or equivalent as an actor, or perhaps the current country of the request.
* **Groups**: on or off for structs or data that belong to a category or satisfy a condition. The `FunWithFlags.Group` protocol can be implemented for types and structs that belong to groups for which a feature flag can be enabled or disabled. For example, one could implement the protocol for a `%User{}` struct to identify administrators.
* **%-of-Time**: globally on for a percentage of the time. It ignores actors and groups. Mutually exclusive with the %-of-actors gate.
* **%-of-Actors**: globally on for a percentage of the actors. It only applies when the flag is checked with a specific actor and is ignored when the flag is checked without actor arguments. Mutually exclusive with the %-of-time gate.

Boolean, Actor and Group gates can express either an enabled or disabled state. The percentage gates can only express an enabled state, as disabling something for a percentage of time or actors is logically equivalent to enabling it for the complementary percentage.

### Gate Priority and Interactions

The priority order is from most to least specific: `Actors > Groups > Boolean > Percentage`, and it applies to both enabled and disabled gates.

For example, a disabled group gate takes precedence over an enabled boolean (global) gate for the entities in the group, and a further enabled actor gate overrides the disabled group gate for a specific entity. When an entity belongs to multiple groups with conflicting toggle status, the disabled group gates have precedence over the enabled ones. The percentage gates are checked last, if present, and they're only checked if no other gate is enabled.

As another example, a flag can have a disabled boolean gate and a 50% enabled %-of-actors gate. When the flag is checked with an actor, it has a (deterministic, consistent and repeatable) 50% chance to be enabled, but when checked without an actor argument it will always be disabled. If we add to the flag a disabled actor gate and an enabled group gate, the flag will be always disabled for the actor, always enabled for any other actor matching the group, have a 50% change to be enabled for any other actor, and always be disabled when checked without actor arguments. If, then, we replace the 50%-of-actors gate with a 50%-of-time gate, the flag will be always disabled for the actor, always enabled for any other actor matching the group, and have a 50% chance to be enabled for any other actor or when checked without an actor argument.

### Boolean Gate

The boolean gate is the simplest one. It's either enabled or disabled, globally. It's also the gate with the second lowest priority (it can mask the percentage gates). If a flag is undefined, it defaults to be globally disabled.

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

Actor gates take precedence over the others, both when they're enabled and when they're disabled. They can be considered as toggle overrides.

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

bruce = %MyApp.User{id: 1, name: "Bruce"}
alfred = %MyApp.User{id: 2, name: "Alfred"}

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

Group gates are similar to actor gates, but they apply to a category of entities rather than specific ones. They can be toggled on or off for the _name of the group_ instead of a specific term.

Group gates take precedence over boolean gates but are overridden by actor gates.

Group names can be binaries or atoms. Atoms are supported for retro-compatibility with versions `<= 0.9` and binaries are therefore preferred. In fact, atoms are internally converted to binaries and are then stored and later retrieved as binaries.

The semantics to determine which entities belong to which groups are application specific.
Entities could have an explicit list of groups they belong to, or the groups could be abstract and inferred from some other attribute. For example, an `:employee` group could comprise all `%User{}` structs with an email address matching the company domain, or an `:admin` group could be made of all users with `%User{admin: true}`.

In order to be affected by a group gate, an entity should implement the `FunWithFlags.Group` protocol. The protocol automatically falls back to a default `Any` implementation, which states that any entity belongs to no group at all. This makes it possible to safely use "normal" actors when querying group gates, and to implement the protocol only for structs and types for which it matters.

The protocol can be implemented for custom structs or literally any other type.


```elixir
defmodule MyApp.User do
  defstruct [:email, admin: false, groups: []]
end

defimpl FunWithFlags.Group, for: MyApp.User do
  def in?(%{email: email}, "employee"), do: Regex.match?(~r/@mycompany.com$/, email)
  def in?(%{admin: is_admin}, "admin"), do: !!is_admin
  def in?(%{groups: list}, group_name), do: group_name in list
end

elisabeth = %MyApp.User{email: "elisabeth@mycompany.com", admin: true, groups: ["engineering", "product"]}
FunWithFlags.Group.in?(elisabeth, "employee")
true
FunWithFlags.Group.in?(elisabeth, "admin")
true
FunWithFlags.Group.in?(elisabeth, "engineering")
true
FunWithFlags.Group.in?(elisabeth, "marketing")
false

defimpl FunWithFlags.Group, for: Map do
  def in?(%{group: group_name}, group_name), do: true
  def in?(_, _), do: false
end

FunWithFlags.Group.in?(%{group: "dumb_tests"}, "dumb_tests")
true
```

With the protocol implemented, actors can be used with the library functions:

```elixir
FunWithFlags.disable(:database_access)
FunWithFlags.enable(:database_access, for_group: "engineering")

FunWithFlags.enabled?(:database_access)
false
FunWithFlags.enabled?(:database_access, for: elisabeth)
true
```

### Percentage of Time Gate

%-of-time gates are similar to boolean gates, but they allow to enable a flag for a percentage of the time. In practical terms, this means that a percentage of the `enabled?()` calls for a flag will return true, regardless of the presence of an actor argument.

When a %-of-time gate is checked a [pseudo-random number is generated](http://erlang.org/doc/man/rand.html#uniform-1) and compared with the percentage value of the gate. If the result of the random roll is lower than the gate's percentage value, the gate is considered enabled. So, at the risk of stating the obvious and for the sake of clarity, a 90% gate is enabled more often than a 10% gate.

%-of-time gates are useful to gradually introduce alternative code paths that either have the same effects of the old ones, or don't have effects visible to the users. This last point is important, because with a %-of-time gate the application will behave differently on a pseudo-random basis.

A good use case for %-of-time gates is to safely test the correctness or performance and load characteristics of an alternative implementation of a functionality.

For example:

```elixir
FunWithFlags.clear(:alternative_implementation)
FunWithFlags.enable(:alternative_implementation, for_percentage_of: {:time, 0.05})

def foo(bar) do
  if FunWithFlags.enabled?(:alternative_implementation) do
    new_foo(bar)
  else
    old_foo(bar)
  end
end
```

The %-of-time gate is incompatible and mutually exclusive with the %-of-actors gate, and it replaces it when it gets set. While there are ways to make them work together, it would needlessly overcomplicate the priority rules.

### Percentage of Actors Gate

%-of-actors gates are similar to the %-of-time gates, but instead of using a pseudo-random chance they calculate the actor scores using a deterministic, consistent and repeatable function that factors in the flag name. At a high level:

```elixir
actor
|> FunWithFlags.Actor.id()
|> sha256_hash(flag_name)
|> hash_to_percentage()
```

Since the scores depend on both the actor ID and the flag name, they're guaranteed to always be the same for each actor-flag combination. At the same time, the same actor will have different scores for different flags, and each flag will have a uniform distribution of scores for all the actors.

Just like for the %-of-time gates, an actor's score is compared with the gate's percentage value and, if lower, the gate will result enabled.

A practical example, based on the `FunWithFlags.Actor` protocol set up from the previous sections:

```elixir
defmodule MyApp.User do
  defstruct [:id, :name]
end

defimpl FunWithFlags.Actor, for: MyApp.User do
  def id(%{id: id}) do
    "user:#{id}"
  end
end

frodo  = %MyApp.User{id: 1, name: "Frodo Baggins"}
sam    = %MyApp.User{id: 2, name: "Samwise Gamgee"}
pippin = %MyApp.User{id: 3, name: "Peregrin Took"}
merry  = %MyApp.User{id: 4, name: "Meriadoc Brandybuck"}

FunWithFlags.Actor.Percentage.score(frodo, :pipeweed)
0.8658294677734375
FunWithFlags.Actor.Percentage.score(sam, :pipeweed)
0.68426513671875
FunWithFlags.Actor.Percentage.score(pippin, :pipeweed)
0.510528564453125
FunWithFlags.Actor.Percentage.score(merry, :pipeweed)
0.2617645263671875

{:ok, true} = FunWithFlags.enable(:pipeweed, for_percentage_of: {:actors, 0.60})

FunWithFlags.enabled?(:pipeweed, for: frodo)
false
FunWithFlags.enabled?(:pipeweed, for: sam)
false
FunWithFlags.enabled?(:pipeweed, for: pippin)
true
FunWithFlags.enabled?(:pipeweed, for: merry)
true

{:ok, true} = FunWithFlags.enable(:pipeweed, for_percentage_of: {:actors, 0.685})

FunWithFlags.enabled?(:pipeweed, for: sam)
true

FunWithFlags.Actor.Percentage.score(pippin, :pipeweed)
0.510528564453125
FunWithFlags.Actor.Percentage.score(pippin, :mushrooms)
0.6050872802734375
FunWithFlags.Actor.Percentage.score(pippin, :palantir)
0.144073486328125
```


Once a %-of-actors gate has been defined for a flag, the same actor will always see the same result (unless its actor or group gates are set, or the flag gets globally enabled). Also, this means that as long the percentage value of the gate will increase and never decrease, actors for which the gate has been enabled will always see it enabled.

This is ideal to gradually roll out new functionality to users.

For example, in a Phoenix application:

```elixir
FunWithFlags.clear(:new_design)
FunWithFlags.enable(:new_design, for_percentage_of: {:actors, 0.2})
FunWithFlags.enable(:new_design, for_group: "beta_testers")


defmodule MyPhoenixApp.MyView do
  use MyPhoenixApp, :view

  def render("my_template.html", assigns) do
    if FunWithFlags.enabled?(:new_design, for: assigns.user) do
      render("new_template.html", assigns)
    else
      render("old_template.html", assigns)
    end
  end
end
```

The %-of-actors gate is incompatible and mutually exclusive with the %-of-time gate, and it replaces it when it gets set. While there are ways to make them work together, it would needlessly overcomplicate the priority rules.

### Clearing a Feature Flag's Rules

Sometimes enabling or disabling a gate is not what you want, and removing that gate's rules would be more correct. For example, if you don't need anymore to explicitly enable or disable a flag for an actor or for a group, and the default state should be used instead, clearing the gate is the right choice.

More examples:

```elixir
alias FunWithFlags.TestUser, as: User
harry = %User{id: 1, name: "Harry Potter", groups: ["wizards", "gryffindor"]}
hagrid = %User{id: 2, name: "Rubeus Hagrid", groups: ["wizards", "gamekeeper"]}
dudley = %User{id: 3, name: "Dudley Dursley", groups: ["muggles"]}
FunWithFlags.disable(:wands)
FunWithFlags.enable(:wands, for_group: "wizards")
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

FunWithFlags.clear(:wands, for_group: "wizards")

FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: harry)
false

FunWithFlags.enable(:magic_powers, for_percentage_of: {:time, 0.0001})
FunWithFlags.clear(:magic_powers, for_percentage: true)
```

For completeness, clearing the boolean gate is also supported.

```elixir
FunWithFlags.enable(:wands)

FunWithFlags.enabled?(:wands)
true
FunWithFlags.enabled?(:wands, for: harry)
true
FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: dudley)
true

FunWithFlags.clear(:wands, boolean: true)

FunWithFlags.enabled?(:wands)
false
FunWithFlags.enabled?(:wands, for: harry)
true
FunWithFlags.enabled?(:wands, for: hagrid)
false
FunWithFlags.enabled?(:wands, for: dudley)
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

* Minimize the load on the persistence layer: feature flags are not toggled _that_ often, and there is no need to query Redis or the DB for each check.
* Be more reliable: it should keep working with the latest cached values even if Redis becomes unavailable, although with the risk of nodes getting out of sync. (if the DB becomes unavailable, feature flags are probably the last of your problems)

Just as Elixir and Phoenix are meant to scale better than Ruby on Rails with high levels of traffic and concurrency, FunWithFlags should aim to be more scalable and reliable than Flipper.

## So, caching, huh?

> There are only two hard things in Computer Science: cache invalidation and naming things.
>
> -- Phil Karlton

The reason to add an ETS cache is that, most of the time, feature flags can be considered static values. Doing a round-trip to the DB (Redis, PostgreSQL or MySQL) is expensive in terms of time and in terms of resources, especially if multiple flags must be checked during a single web request. In the worst cases, the load on the DB can become a cause of concern, a performance bottleneck or the source of a system failure.

Often the solution is to memoize the flag values _in the context of the web request_, but the approach can be extended to the scope of the entire server. This is what FunWithFlags does, as each application node/instance caches the flags in an ETS table.

Of course, caching adds a different kind of complexity and there are some pros and cons. When a flag is created or updated the ETS cache on the local node is updated immediately, and the main problem is synchronizing the flag data across the other application nodes that should share the same view of the world.

For example, if we have two or more nodes running the application, and on one of them an admin user updates a flag that the others have already cached, or creates a flag that the others have already looked up (and cached as "disabled"), then the other nodes must  be notified of the changes.

FunWithFlags uses three mechanisms to deal with the problem:

1. Use PubSub to emit change notifications. All nodes subscribe to the same channel and reload flags in the ETS cache when required.
2. If that fails, the cache has a configurable TTL. Reading from the DB every few minutes is still better than doing so 30k times per second.
3. If that doesn't work, it's possible to disable the cache and just read from the DB all the time. That's what Flipper does.

In terms of performance, very synthetic benchmarks (where the DBs run on the same machine as the Beam code, so with no network hop but sharing the CPU) show that the ETS cache makes querying the FunWithFlags interface between 10 and 20 times faster than going directly to Redis, and between 20 and 40 times faster than going directly to Postgres. The variance depends on the complexity of the flag data to be retrieved.

## To Do

* Add some optional randomness to the TTL, so that Redis or the DB don't get hammered at constant intervals after a server restart.

## Installation

The package can be installed by adding `fun_with_flags` to your list of dependencies in `mix.exs`.

In order to have a small installation footprint, the dependencies for the different adapters are all optional. You must explicitly require the ones you wish to use.

```elixir
def deps do
  [
    {:fun_with_flags, "~> 1.11.0"},

    # either:
    {:redix, "~> 0.9"},
    # or:
    {:ecto_sql, "~> 3.0"},

    # optionally, if you don't want to use Redis' builtin pubsub
    {:phoenix_pubsub, "~> 2.0"},
  ]
end
```

Using `ecto_sql` for persisting the flags also requires an ecto adapter, e.g. `postgrex`, `mariaex` or `myxql`. Please refer to the Ecto documentation for the details.

Since FunWithFlags depends on an Elixir more recent than 1.4, there is [no need to explicitly declare the application](https://github.com/elixir-lang/elixir/blob/v1.4/CHANGELOG.md#application-inference).

If you need to customize how the `:fun_with_flags` application is loaded and started, refer to the [Application Start Behaviour](#application-start-behaviour) section, below in this document.

## Configuration

The library can be configured in host applications through Mix and the `config.exs` file. This example shows some default values:

```elixir
config :fun_with_flags, :cache,
  enabled: true,
  ttl: 900 # in seconds

# the Redis persistence adapter is the default, no need to set this.
config :fun_with_flags, :persistence,
  [adapter: FunWithFlags.Store.Persistent.Redis]

# this can be disabled if you are running on a single node and don't need to
# sync different ETS caches. It won't have any effect if the cache is disabled.
# The Redis PuSub adapter is the default, no need to set this.
config :fun_with_flags, :cache_bust_notifications,
  [enabled: true, adapter: FunWithFlags.Notifications.Redis]

# Notifications can also be disabled, which will also remove the Redis/Redix dependency
config :fun_with_flags, :cache_bust_notifications, [enabled: false]
```

When using Redis for persistence and/or cache-busting PubSub it is necessary to configure the connection to the Redis instance. These options can be omitted if Redis is not being used. For example, the defaults:

```elixir
# the Redis options will be forwarded to Redix.
config :fun_with_flags, :redis,
  host: "localhost",
  port: 6379,
  database: 0

# a URL string can be used instead
config :fun_with_flags, :redis, "redis://localhost:6379/0"

# or a {URL, [opts]} tuple
config :fun_with_flags, :redis, {"redis://localhost:6379/0", socket_opts: [:inet6]}

# a {:system, name} tuple can be used to read from the environment
config :fun_with_flags, :redis, {:system, "REDIS_URL"}
```

[Redis Sentinel](https://redis.io/docs/manual/sentinel/) is also supported. See the [Redix docs](https://github.com/whatyouhide/redix/tree/v1.1.5#redis-sentinel) for more details.

```elixir
config :fun_with_flags, :redis,
  sentinel: [
    sentinels: ["redis:://locahost:1234/1"],
    group: "primary",
  ],
  database: 5
```

### Persistence Adapters

The library comes with two persistence adapters for the [`Redix`](https://hex.pm/packages/redix) and [`Ecto`](https://hex.pm/packages/ecto) libraries, that allow to persist feature flag data in Redis, PostgreSQL, MySQL, or SQLite. In order to use any of them, you must declare the correct optional dependency in the Mixfile (see the [installation](#installation) instructions, above).

The Redis adapter is the default and there is no need to explicitly declare it. All it needs is the Redis connection configuration.

In order to use the Ecto adapter, an Ecto repo must be provided in the configuration. FunWithFlags expects the Ecto repo to be initialized by the host application, which also needs to start and supervise any required processes. If using Phoenix this is managed automatically by the framework, and it's fine to use the same repo used by the rest of the application.

Only PostgreSQL (via [`postgrex`](https://hex.pm/packages/postgrex)), MySQL (via [`mariaex`](https://hex.pm/packages/mariaex) or [`myxql`](https://hex.pm/packages/myxql)), and SQLite (via [`ecto_sqlite3`](https://hex.pm/packages/ecto_sqlite3)) are supported at the moment. Support for other RDBMSs might come in the future.

To configure the Ecto adapter:

```elixir
# Normal Phoenix and Ecto configuration.
# The repo can either use the Postgres or MySQL adapter.
config :my_app, ecto_repos: [MyApp.Repo]
config :my_app, MyApp.Repo,
  username: "my_db_user",
  password: "my secret db password",
  database: "my_app_dev",
  hostname: "localhost",
  pool_size: 10

# FunWithFlags configuration.
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: MyApp.Repo,
  ecto_table_name: "your_table_name", # optional, defaults to "fun_with_flags_toggles"
  ecto_primary_key_type: :binary_id # optional, defaults to :id
  # For the primary key type, see also: https://hexdocs.pm/ecto/3.10.3/Ecto.Schema.html#module-schema-attributes
```

It's also necessary to create the DB table that will hold the feature flag data. To do that, [create a new migration](https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Gen.Migration.html) in your project and copy the contents of [the provided migration file](https://github.com/tompave/fun_with_flags/blob/master/priv/ecto_repo/migrations/00000000000000_create_feature_flags_table.exs). Then [run the migration](https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html).

When using the Ecto persistence adapter, FunWithFlags will annotate all queries using the [Ecto Repo Query API](https://hexdocs.pm/ecto/3.8.4/Ecto.Repo.html#query-api) with a custom option: `[fun_with_flags: true]`. This is done to make it easier to identify FunWithFlags queries when working with Ecto customization hooks, e.g. the [`Ecto.Repo.prepare_query/3` callback](https://hexdocs.pm/ecto/3.8.4/Ecto.Repo.html#c:prepare_query/3). Since this sort of annotations via custom query options are only useful with the Ecto Query API ([context](https://elixirforum.com/t/proposal-prepare-query-for-write-operations/50510)), other repo functions are not annotated with the custom option.

#### Ecto Multi-tenancy

If you followed the Ecto guide on setting up [multi-tenancy with foreign keys](https://hexdocs.pm/ecto/3.8.4/multi-tenancy-with-foreign-keys.html), you must add an exception for queries originating from FunWithFlags. As mentioned in the section above, these queries have a custom query option named `:fun_with_flags` set to `true`:

```elixir
# Sample code, only relevant if you followed the Ecto guide on multi tenancy with foreign keys.
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app

  require Ecto.Query

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      # add the check for opts[:fun_with_flags] here:
      opts[:skip_org_id] || opts[:schema_migration] || opts[:fun_with_flags] ->
        {query, opts}

      org_id = opts[:org_id] ->
        {Ecto.Query.where(query, org_id: ^org_id), opts}

      true ->
        raise "expected org_id or skip_org_id to be set"
    end
  end
end
```

#### Ecto Custom Primary Key Types

The library defaults to using an integer (`bigserial`) as the type of the `id` primary key column. If, for any reason, you need the ID to be a UUID, you can configure it to be of type `:binary_id`. To do that, you need to:

  1. Set the `:ecto_primary_key_type` configuration option to `:binary_id`.
  2. Use `:binary_id` as the type of the `:id` column in the [provided migration file](https://github.com/tompave/fun_with_flags/blob/master/priv/ecto_repo/migrations/00000000000000_create_feature_flags_table.exs).

### PubSub Adapters

The library comes with two PubSub adapters for the [`Redix`](https://hex.pm/packages/redix) and [`Phoenix.PubSub`](https://hex.pm/packages/phoenix_pubsub) libraries. In order to use any of them, you must declare the correct optional dependency in the Mixfile. (see the [installation](#installation) instructions, below)

The Redis PubSub adapter is the default and doesn't need to be explicitly configured. It can only be used in conjunction with the Redis persistence adapter however, and is not available when using Ecto for persistence. When used, it connects directly to the Redis instance used for persisting the flag data.

The Phoenix PubSub adapter uses the high level API of `Phoenix.PubSub`, which means that under the hood it could use either its PG2 or Redis adapters, and this library doesn't need to know. It's provided as a convenient way to leverage distributed Erlang when using FunWithFlags in a Phoenix application, although it can be used independently (without the rest of the Phoenix framework) to add PubSub to Elixir apps running on Erlang clusters.  
FunWithFlags expects the `Phoenix.PubSub` process to be started by the host application, and in order to use this adapter the client (name or PID) must be provided in the configuration.

For example, in Phoenix (>= 1.5.0) it would be:

```elixir
# normal Phoenix configuration
config :my_app, MyApp.Web.Endpoint,
  pubsub_server: MyApp.PubSub

# FunWithFlags configuration
config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: MyApp.PubSub
```

Or, without Phoenix:

```elixir
# possibly in the application's supervision tree
children = [
  {Phoenix.PubSub, [name: :my_pubsub_process_name, adapter: Phoenix.PubSub.PG2]}
]
opts = [strategy: :one_for_one, name: MyApp.Supervisor]
{:ok, _pid} = Supervisor.start_link(children, opts)

# config/config.exs
config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: :my_pubsub_process_name
```

## Extensibility

### Custom Persistence Adapters

This library aims to be extensible and allows users to provide their own persistence layer.

This is supported through [`FunWithFlags.Store.Persistent`](https://github.com/tompave/fun_with_flags/blob/master/lib/fun_with_flags/store/persistent.ex), a generic persistence [behaviour](https://hexdocs.pm/elixir/typespecs.html#behaviours) that is adopted by the builtin Redis and Ecto adapters.

Custom persistence adapters can adopt the behaviour and then be configured as the persistence module in the Mix config of the user applications.

For example, an application can define this module:

```elixir
defmodule MyApp.MyAlternativeFlagStore do
  @behaviour FunWithFlags.Store.Persistent
  # implement all the behaviour's callback
end
```

And then configure the library to use it:

```elixir
config :fun_with_flags, :persistence, adapter: MyApp.MyAlternativeFlagStore
```

## Application Start Behaviour

As explained in the [Installation](#installation) section, above in this document, the `:fun_with_flags` application will start automatically when you add the package as a dependency in your Mixfile. The `:fun_with_flags` application starts its own supervision tree which manages all required processes and is provided by the `FunWithFlags.Supervisor` module.

Sometimes, this can cause issues and race conditions if FunWithFlags is configured to rely on Erlang processes that are owned by another application. For example, if you have configured the `Phoenix.PubSub` cache-busting notification adapter, one of FunWithFlag's processes will immediately try to subscribe to its notifications channel using the provided PubSub process identifier. If that process is not available, FunWithFlags will retry a few times and then give up and raise an exception. This will become a problem if you're using FunWithFlags in a large application (e.g. a Phoenix app) and the `:fun_with_flags` application starts much faster than the Phoenix supervision tree.

In these cases, it's better to directly control how FunWithFlags starts its processes.

The first step is to add the `FunWithFlags.Supervisor` module directly to the supervision tree of the host application. For example, in a Phoenix app it would look like this:

```diff
defmodule MyPhoenixApp.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      MyPhoenixApp.Repo,
      MyPhoenixAppWeb.Telemetry,
      {Phoenix.PubSub, name: MyPhoenixApp.PubSub},
      MyPhoenixAppWeb.Endpoint,
+     FunWithFlags.Supervisor,
    ]

    opts = [strategy: :one_for_one, name: MyPhoenixApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
```

Then it's necessary to configure the Mix project to not start the `:fun_with_flags` application automatically. This can be accomplished in the Mixfile in a number of ways, for example: (**Note**: These are alternative solutions, you don't need to do both. You must decide which is more appropriate for your setup.)

* **Option A**: Declare the `:fun_with_flags` dependency with either the `runtime: false` or `app: false` options. ([docs](https://hexdocs.pm/mix/1.11.3/Mix.Tasks.Deps.html#module-dependency-definition-options))

```diff
- {:fun_with_flags, "~> 1.6"},
+ {:fun_with_flags, "~> 1.6", runtime: false},
```

If you use releases then you'll also need to modify the `releases` section in `mix.exs` so that it loads the `fun_with_flags` application explicitly (since `runtime: false` / `app: false` will exclude it from the assembled release).

```diff
def project do
  [
    app: :my_phoenix_app,
+   releases: [
+     my_phoenix_app: [
+       applications: [
+         fun_with_flags: :load
+       ]
+    ]
  ]
end
```

* **Option B**: Declare that the `:fun_with_flags` application is managed directly by your host application ([docs](https://hexdocs.pm/mix/1.11.3/Mix.Tasks.Compile.App.html)).

```diff
  def application do
    [
      mod: {MyPhoenixApp.Application, []},
+     included_applications: [:fun_with_flags],
      extra_applications: [:logger, :runtime_tools]
    ]
  end
```

The result of those changes is that the `:fun_with_flags` application won't be loaded and started automatically, and therefore the FunWithFlags supervision tree won't risk to be started before the other processes in the host Phoenix application. Rather, the supervision tree will start alongside the other core Phoenix processes.

One final note on this topic is that if you're also using [`FunWithFlags.UI`](https://github.com/tompave/fun_with_flags_ui) (refer to the [Web Dashboard](#web-dashboard) section, above in this document), then that will need to be configured as well. The reason is that `:fun_with_flags` is a dependency of `:fun_with_flags_ui`, so including the latter as a dependency will cause the former to be auto-started despite the configuration described above. To avoid this, the same configuration should be used for the `:fun_with_flags_ui` dependency, regardless of the approach used (Option A: `runtime: false`, `app: false`; or Option B: `included_applications`).


## Testing

This library depends on Redis, PostgreSQL and MySQL, and you'll need them installed and running on your system in order to run the complete test suite. The tests will use the [Redis db number 5](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_utils.ex#L4) and then clean after themselves, but it's safer to start Redis in a directory where there is no `dump.rdb` file you care about to avoid issues. The Ecto tests will use the SQL sandbox and all transactions will be automatically rolled back.

To setup the test DB for the Ecto persistence tests, run:

```
MIX_ENV=test PERSISTENCE=ecto mix do ecto.create, ecto.migrate              # for postgres
rm -rf _build/test/lib/fun_with_flags/
MIX_ENV=test PERSISTENCE=ecto RDBMS=mysql mix do ecto.create, ecto.migrate  # for mysql
rm -rf _build/test/lib/fun_with_flags/
MIX_ENV=test PERSISTENCE=ecto RDBMS=sqlite mix do ecto.create, ecto.migrate  # for sqlite

```

Then, to run all the tests:
```
$ mix test.all
```

The `test.all` task will run the test suite multiple times with different configurations to exercise a matrix of options and adapters.

The Mixfile defines a few other helper tasks that allow to run the test suite with some more specific configurations.

## Development

Like for testing, developing FunWithFlags requires local installations of Redis, PostgreSQL and MySQL. For work that doesn't touch the persistence adapters too closely, it's possibly simpler to just run FunWithFlags with Redis and then let CI run the tests with the other adapters.

A common workflow is to run the tests and interact with the package API in `iex`.

With the [default configuration](https://github.com/tompave/fun_with_flags/blob/master/config/config.exs), `iex -S mix` will compile and load FunWithFlags with Redis persistence and Redis PubSub. To compile and run the package in `iex` with Ecto and Phoenix PubSub support instead, use these commands:

```shell
bin/console_ecto postgres
bin/console_ecto mysql
```

This package uses the [credo](https://hex.pm/packages/credo) and [dialyxir](https://hex.pm/packages/dialyxir) ([dialyzer](https://erlang.org/doc/man/dialyzer.html)) packages to help with local development. Their mix tasks can be executed in the root directory of the project:

```shell
mix credo
mix dialyzer
```

### Working with PubSub Locally

It's possible to test the PubSub functionality locally, in `iex`.

When using Redis, it's enough to start two `iex -S mix` sessions in two terminals, and they'll talk with one another via Redis.

When using `Phoenix.PubSub` (which is typically the case with `Ecto`), then the process is similar but you must establish a connection between the two Erlang nodes running in the two terminals. There are a number of ways to do this, and the simplest is to do it manually within `iex`.

Steps:

1. Run `bin/console_pubsub foo` in one terminal.
2. Run `bin/console_pubsub bar` in another terminal.
3. In either terminal, grab the current name with `Node.self()`. (The name will also be shown in the `iex` prompts).
4. In the other terminal, run `Node.connect(:"THE_OTHER_NODE_NAME")`. Keep in mind that the names are atoms.
5. In either terminal, run `Node.list()` to check that there is a connection.

Done that, modifying any flag data in either terminal will notify the other one via PubSub.
