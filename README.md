# FunWithFlags

[![Build Status](https://travis-ci.org/tompave/fun_with_flags.svg?branch=master)](https://travis-ci.org/tompave/fun_with_flags)
[![Hex.pm](https://img.shields.io/hexpm/v/fun_with_flags.svg)](https://hex.pm/packages/fun_with_flags)
[![hexdocs.pm](https://img.shields.io/badge/docs-0.3.0-brightgreen.svg)](https://hexdocs.pm/fun_with_flags/)

FunWithFlags, the Elixir feature flag library.

This readme refers to the `master` branch. For the latest version released on Hex, please check [the readme published with the docs](https://hexdocs.pm/fun_with_flags/readme.html).

---

FunWithFlags is an OTP application that provides a 2-level storage to save and retrieve feature flags and an Elixir API to toggle and query them.

It stores flag information in Redis for persistence and syncronization across different nodes, but it also maintains a local cache in an ETS table for fast lookups. When flags are added or toggled on a node, the other nodes are notified via Redis PubSub and reload their local ETS caches.

## Usage

FunWithFlags has a simple API to query and toggle feature flags. Most of the time, you'll call `FunWithFlags.enabled?/2` with the name of the flag and optional arguments.

Different kinds of toggle gates are supported:

* boolean (on, off);
* actors (on or off for specific structs or data);
* _soon_ ~~groups (or or off for structs or data that satisfy a condition).~~

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

This allows you to enable or disable a flag for one or more specific entities. This can be useful to showcase a work-in-progress feature to someone, to gradually rollout a functionality (e.g. your actor could be a country), or to dynamically disable some features in some contexts (e.g. you realize that a critical error is only raised in one specific country).

Actor gates take precendence over the others, both when they're enabled and when they're disabled.

In order to be used as an actor, an entity must implement the `FunWithFlags.Actor` protocol. This is a plain Elixir protocol and can be implemented for custom structs or literally any other type. An example is below, and more can be found in the [test support files](https://github.com/tompave/fun_with_flags/blob/master/test/support/protocols.ex).


```elixir
defmodule MyApp.User do
  defstruct [:id, :name]
end

defimpl FunWithFlags.Actor, for: MyApp.User do
  def id(user) do
    "user:#{user.id}"
  end
end

bruce = %User{id: 1, name: "Bruce"}
alfred = %User{id: 1, name: "Alfred"}

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

Actor identifiers must be globally unique strings. A common technique to support multiple kinds of actors is to namespace the IDs:

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

1. Use Redis PubSub to emit change notifications. All nodes subscribe to the same channel and reload flags in the ETS cache when required.
2. If that fails, the cache has a configurable TTL. Reading from redis every few minutes is still better than doing so 30k times per second.
3. If that doesn't work, it's possible to disable the cache and just read from Redis all the time. That's what Flipper does.


## Features

A grab bag. I'll add more items as I get closer to a stable release.

* Simple boolean flags: either ON or OFF.
* Flags are persisted in Redis and available on application restart.
* In-process ETS cache. On lookup, the library checks the cache first. If the ETS table doesn't contain a flag, it falls back to Redis and copies the value into the cache. Subsequent lookups won't hit Redis. The ETS table is empty when the application starts. Writes to the ETS table are managed by a GenServer and are serial, while any other process can read from it concurrently.
* Creating or toggling a flag will update both the ETS cache and Redis.
* Both the ETS cache and the Redis connection are in a supervision tree. The [Redix](https://hex.pm/packages/redix) adapter will try to reconnect to Redis if the connection is lost.
* If the connection to Redis is lost, the application will continue to work with the known values from the ETS cache, even if normally they might be considered expired (because of the TTL). If an unknown flag is looked up when Redis is unavailable a runtime exception will be raised.
* Several nodes can connect to the same Redis and share the flag settings. Each one will hit Redis the first time a flag is looked up, and then will populate its ETS cache.
* The ETS cache is enabled by default, but it can be disabled to only use Redis.
* The ETS cache supports a global TTL, expressed in seconds. It defaults to 900s (15 minutes). After expiration, flags are re-fetched from Redis. This allows multiple nodes to use the same redis, and slowly acquire and cache flags that have been changed by another node.
* Distributed cache-busting. When a flag is persisted in Redis (created or updated), use Redis PubSub to notify all other Elixir nodes. When a node receives PubSub message it will reload the local cached copy of the flag. A node will ignore messages originated from the node itself (otherwise the originator node would reload the flag too).
* Actor gates: enable or disable a flag for a specific data structure or primitive value.

### To do next

* Implement other "gates": at least ~~actors~~ (done) and groups.
* Add logging with proper error reporting.
* Add a web GUI, as a plug, ideally in another package.
* Add some optional randomness to the TTL, so that Redis doesn't get hammered at constant intervals after a server restart.


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
```



## Installation

The package can be installed by adding `fun_with_flags` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fun_with_flags, "~> 0.3.0"}]
end
```

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

The `test.all` task will run the default `mix test` task with `MIX_ENV=test`, and then will switch to a custom `MIX_ENV=test_no_cache` environment where the ETS cache is disabled and re-run the integration tests.

## Why not Distributed Erlang?

Redis PubSub, huh? Why not Distributed Erlang's inter-node messages?

Because there are people who want to run Elixir and Phoenix on Heroku, where nodes are isolated on the dynos. Distributed Erlang unfortunately doesn't work on Heroku, but sharing data through Redis works and it's a common pattern in a lot of frameworks.

Another reason is that Redis is already a dependency for data persistence across restarts, so adding PubSub is not a problem. Redis is a good tool to store this kind of data. A pure Elixir solution could use Mnesia, DETS, or dump the ETS cache to files, but these approaches would still not work if running on a PaaS like Heroku, and it would be hard to quickly syncronize new nodes if more are started in a burst.

Also, a lot of people approaching Elixir come from a Rails background, and in this case my priority is to make this library work on setups that are familiar to Rails developers. The goal is to facilitate the adoption of Elixir and Phoenix by growing a familiar ecosystem.

One of the reasons why Rails has become popular is its ease of use and deplployment. Of course it hasn't always been like that, and at the beginning it required complex setups with Capistrano, Mongrels and reverse proxys. In the meantime, however, the ecosystem has matured and PaaS have become a thing. Some of today's most popular frameworks, too, have been built to leverage the ease of deployment provided by PaaS vendors.

I have a feeling that the adoption of Phoenix will grow faster if the ecosystem supports the techniques that developers are already familiar with. Distributed Erlang can be seen as the next level of deployment and setup.

With that out of the way, making FunWithFlags work with Distributed Erlang instead of Redis PubSub wouldn't be too hard. Feel free to propose a design for an adapter interface or send a PR.
