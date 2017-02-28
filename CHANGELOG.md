# Changelog

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
** Cache busting with TTLs
** Cache busting with Redis PubSub
* Resistant to Redis connection issues if the values are cached
* Option to disable the ETS cache (Redis-only mode)


## v0.0.x

Unstable releases.


