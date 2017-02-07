# FunWithFlags

[![Build Status](https://travis-ci.org/tompave/fun_with_flags.svg?branch=master)](https://travis-ci.org/tompave/fun_with_flags)
[![Hex.pm](https://img.shields.io/hexpm/v/fun_with_flags.svg)](https://hex.pm/packages/fun_with_flags)
[![hexdocs.pm](https://img.shields.io/badge/docs-0.0.3-brightgreen.svg)](https://hexdocs.pm/fun_with_flags/)

FunWithFlags, the Elixir feature flag library.

**This library is still a work in progress and is not ready to use**

This readme refers to the `master` branch. For the latest version released on Hex, please check [the readme published with the docs](https://hexdocs.pm/fun_with_flags/readme.html).

## Goals

This library is meant to be an OTP application that provides an Elixir API to toggle and query feature flags and an (authenticated) web UI for administrators.

It should store feature flag information in Redis for persistence and syncronize different nodes, but it should also maintain a local cache in an ETS table for fast lookup. When flags are added or toggled, nodes should be notified (via Redis PubSub or polling) and update their local ETS representation.

Different kind of feature flags should be supported:
* simple (on, off);
* actors (on or off for specific structs or data);
* groups (or or off for structs or data that satisfy a condition).

The planned functionality of this library is heavily inspired by the [flipper Ruby gem](https://github.com/jnunemaker/flipper), although with a focus on:
* decreasing the load on Redis (feature flags are not toggled _that_ often, there is no need to query Redis for each check);
* making it more reliable (it should keep working with the last cached values if Redis becomes unavailable, although nodes can be out of sync).

Just as Elixir and Phoenix are meant to scale better than Ruby on Rails with high levels of traffic and concurrency, FunWithFlags should aim to be more scalable than Flipper.

## Status and Roadmap

### Done

* Simple boolean flags: either ON or OFF.
* Flags are persisted in Redis and available on application restart.
* In-process ETS cache. On lookup, the library checks the cache first. If the ETS table doesn't contain a flag, it falls back to Redis and copies the value into the cache. Subsequent lookups won't hit Redis. The ETS table is empty when the application starts. Writes to the ETS table are managed by a GenServer and are serial, while any other process can read from it concurrently.
* Creating or toggling a flag will update both the ETS cache and Redis.
* Both the ETS cache and the Redis connection are in a supervision tree. The [Redix](https://hex.pm/packages/redix) adapter will try to reconnect to Redis if the connection is lost.
* If the connection to Redis is lost, the application will continue to work with the known values from the ETS cache. If an unknown flag is looked up when Redis is unavailable it will default to the disabled state.
* Several nodes can connect to the same Redis and share the flag settings. Each one will hit Redis the first time a flag is looked up, and then will populate its ETS cache.

### Next / Problems

* When two or more nodes are using the same Redis, and one of them updates a flag that the others have already cached, or creates a flag that the others have already looked up (and cached as "disabled"), then the other nodes will not be notified of the changes.
    * Use Redis PubSub to emit change notifications.
    * Add a TTL to the ETS cache (use [ConCache](https://hex.pm/packages/con_cache)?).
    * Add polling to refresh the cache from Redis every X seconds (not ideal).
* Implement other "gates": at least actors and groups.


## Usage

Still a work in progress, expect breaking changes.

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


## Installation

The package can be installed by adding `fun_with_flags` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fun_with_flags, "~> 0.0.3"}]
end
```


