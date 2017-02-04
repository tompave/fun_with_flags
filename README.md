# FunWithFlags

[![Build Status](https://travis-ci.org/tompave/fun_with_flags.svg?branch=master)](https://travis-ci.org/tompave/fun_with_flags)
[![Hex.pm](https://img.shields.io/hexpm/v/fun_with_flags.svg)](https://hex.pm/packages/fun_with_flags)
[![hexdocs.pm](https://img.shields.io/badge/docs-0.0.2-brightgreen.svg)](https://hexdocs.pm/fun_with_flags/api-reference.html)

FunWithFlags, the Elixir feature flag library.

**This library is still a work in progress and is not ready to use**

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
  [{:fun_with_flags, "~> 0.0.1"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/fun_with_flags](https://hexdocs.pm/fun_with_flags).

