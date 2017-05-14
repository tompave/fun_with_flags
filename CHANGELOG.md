# Changelog

## Unreleased

* Internal changes to better support different adapters.
* More rationale test setup.

## v0.7.1

Bug fixes:

* Resolved an issue with the PubSub connection process that would crash the entire supervision tree in case of abrupt disconnection from Redis. Ops!

## v0.7.0

New Features:

* `FunWithFlags.all_flags/0` is now public and documented.
* Added `FunWithFlags.all_flags_names/0`, public and documented.
* Added proper log statements via the Elixir `Logger`. Setting the log level to `debug` will print cache busting info, for example.

Internal changes:

* Updated the `redix` and `redix_pubsub` dependencies.
* Extracted the private persistence and notifications modules into a redis-specific namespace. Added a config option to customize the adapters on startup, and an internal API that allows to develop other adapters to use alternative persistence and notification layers. The persistence adapters are responsible for declaring their own notifications module (if any). The provided default ones keep using Redis, and they work in tandem. At the moment, no official support for other adapters is planned, `redix` stays as a dependency.


## v0.6.0

New features:

* Added `FunWithFlags.clear/2` to delete a specific gate or an entire flag. This is useful if you don't need an actor or group override and want to use the default boolean rule instead. Clearing a flag or a gate uses the same PubSub cache busting functionality used when updating a flag.
* Added `FunWithFlags.all_flags/0`, to return a list of all the flags stored in Redis. Undocumented because it's meant to build a GUI.

## v0.5.0

Added the `Group` protocol and group gates. It's now possible to enable or disable a flag for a group name and implement `Group` for types and structs that should belong to groups.

## v0.4.0

Added the `Actor` protocol and actor gates. It's now possible to implement `Actor` for some type or struct and then enable or disable a flag for some specific values.

## v0.3.0

Always raise exceptions if Redis becomes unavailable _and_ there is no cached value (expired or not). This means that both with or without cache, failures to load a flag's data will never be silently converted to the flag being disabled.

## v0.2.0

Significant internal rewrite: use structures instead of raw booleans. Given the scope of the changes and the fact that this is still a `0.x` release, bump the version number.

## v0.1.1

* Enhancements
    * Treat cache misses and expired cached values differently. If Redis becomes unavailable, and an expired value is available in the cache, use the expired value even though normally it would be discarded.


## v0.1.0

First usable release with the a stable initial feature set.

* Simple boolean flags
* Elixir API to enable, disable and query the flags
* Supervision tree, embeddable in host applications
* Persistence in Redis
* ETS cache
    * Cache busting with TTLs
    * Cache busting with Redis PubSub
* Resistant to Redis connection issues if the values are cached
* Option to disable the ETS cache (Redis-only mode)


## v0.0.x

Unstable releases.


