# Changelog

## v1.11.0

* Add support for Elixir 1.15. Drop support for Elixir 1.12. Elixir >= 1.13 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* Drop support for Erlang/OTP 23, and Erlang/OTP >= 24 is now required. Dropping support for older versions of Erlang/OTP simply means that this package is not tested with them in CI, and that no compatibility issues are considered bugs.
* Remove from the repo the [DB migration](https://github.com/tompave/fun_with_flags/blob/v1.1.0/priv/ecto_repo/migrations/00000000000001_ensure_columns_are_not_null.exs) added in [v1.1.0](https://github.com/tompave/fun_with_flags/blob/master/CHANGELOG.md#v110) (November 2018), as an upgrade step. After almost 5 years, chances are that users of the library are already using the correct schema, and that extra "upgrade" migration is incompatible with RDBMS other than Postgres and MySQL.
* Add support for SQLite with the [`ecto_sqlite3`](https://hex.pm/packages/ecto_sqlite3) adapter. (Thanks [tylerbarker](https://github.com/tylerbarker), [pull/151](https://github.com/tompave/fun_with_flags/pull/151))
* Add support for text (binary) primary key columns with the Ecto adapter. (Thanks [whatyouhide](https://github.com/whatyouhide) and [vinniefranco](https://github.com/vinniefranco), [pull/156](https://github.com/tompave/fun_with_flags/pull/156) and [pull/129](https://github.com/tompave/fun_with_flags/pull/129))

## v1.10.1

* Redis notifications adapter: minor internal changes to what data is passed to the supervisor in the child spec. ([pull/148](https://github.com/tompave/fun_with_flags/pull/148))
* Redis notifications adapter: fix an issue that would arise when configuring both a Redis URL string and key-word options (this config API was introduced in v1.10.0): the config would work for the Redis persistence adapter, but not for the Redis notifications adapter. (Thanks [iamvery](https://github.com/iamvery), [pull/149](https://github.com/tompave/fun_with_flags/pull/149))

## v1.10.0

* Add support for Elixir 1.14. Drop support for Elixir 1.11. Elixir >= 1.12 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* Drop support for Erlang/OTP 22, and Erlang/OTP >= 23 is now required. Dropping support for older versions of Erlang/OTP simply means that this package is not tested with them in CI, and that no compatibility issues are considered bugs.
* Ecto persistence adapter: FunWithFlags will now pass a custom option when using the [Ecto Repo Query API](https://hexdocs.pm/ecto/3.8.4/Ecto.Repo.html#query-api): `[fun_with_flags: true]`. This is done to make it easier to identify FunWithFlags queries when working with Ecto customization hooks, e.g. the [`Ecto.Repo.prepare_query/3` callback](https://hexdocs.pm/ecto/3.8.4/Ecto.Repo.html#c:prepare_query/3). (Thanks [SteffenDE](https://github.com/SteffenDE), [pull/143](https://github.com/tompave/fun_with_flags/pull/143))
* Redis persistence adapter: added support to configure Redis with a `{"redis URL", [...kw opts]}` tuple, [as is supported in Redix itself](https://hexdocs.pm/redix/1.2.0/Redix.html#start_link/2). (Thanks [iamvery](https://github.com/iamvery), [pull/145](https://github.com/tompave/fun_with_flags/pull/145))

## v1.9.0

* Drop support for Elixir 1.10. Elixir >= 1.11 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* Relax supported versions of `postgrex` to allow `~> 0.16`.
* Use [`Application.compile_env/3`](https://hexdocs.pm/elixir/1.13.3/Application.html#compile_env/3) to read the persistence config at compile time, which is used to configure the DB table name when using the Ecto persistence adapter (among other things). This fixes another instance of the issue where users of the package would change the config after compilation and observe unexpected inconsistencies and errors. ([pull/130](https://github.com/tompave/fun_with_flags/pull/130))
* Redis adapters: add support to configure [Redis Sentinel](https://redis.io/docs/manual/sentinel/). Please see the [Redix docs](https://github.com/whatyouhide/redix/tree/v1.1.5#redis-sentinel) for more details. (Thanks [parkdoyeon](https://github.com/parkdoyeon), [pull/107](https://github.com/tompave/fun_with_flags/pull/107).)
* More precise conditional checks when deciding whether Ecto files should be compiled. ([pull/140](https://github.com/tompave/fun_with_flags/pull/140))
* Improved documentation for running the package in a custom supervision tree, when using releases. (Thanks [zaid](https://github.com/zaid), [pull/139](https://github.com/tompave/fun_with_flags/pull/139))

## v1.8.1

* Lock `postgrex` dependency to `< 0.16`. Version `0.16` requires Elixir 1.11 ([changelog](https://github.com/elixir-ecto/postgrex/blob/master/CHANGELOG.md#v0160-2022-01-23)) and it doesn't compile with Elixit 1.10, which FunWithFlags still supports.

## v1.8.0

* Add support for Elixir 1.13. Drop support for Elixir 1.9. Elixir >= 1.10 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* Removed all uses of [`defdelegate/2`](https://hexdocs.pm/elixir/1.13.0/Kernel.html#defdelegate/2). They caused some references to configured modules (that can change according to the config) to be reified at compile time, which lead to unexpected behaviour. They've been replaced with plain old function definitions that do the same job. (Thanks [connorlay](https://github.com/connorlay), [pull/111](https://github.com/tompave/fun_with_flags/pull/111).)
* Local dev: Update the config for the library to use [`Config`](https://hexdocs.pm/elixir/1.13.0/Config.html) instead of the deprecated [`Mix.Config`](https://hexdocs.pm/mix/1.13.0/Mix.Config.html). For the avoidance of doubt: this has no effect when using the package in your projects, because the `config/*.exs` files are not present in the bundles downloaded from Hex.pm.
* Use [`Application.compile_env/3`](https://hexdocs.pm/elixir/1.13.0/Application.html#compile_env/3) to read the cache configuration at compile-time, which is used to define a module attribute (therefore, set at compile-time). That part of the config is compiled into a module attribute for performance reasons, and it has been a long standing issue because users of the package would get confused by their config changes not being reflected in an already compiled application ([link to relevant section in previous version of the readme](https://github.com/tompave/fun_with_flags/tree/v1.7.0#configuration-changes-have-no-effect-in-mix_envdev)). Now, if the relevant configuration changes, users will get a [clear error](https://github.com/elixir-lang/elixir/blob/v1.10/CHANGELOG.md#tracking-of-compile-time-configuration).
* Improve error handling in different layers of the package. From the persistence adapters all the way to the public functions of the top-level module. In practice, this means that some situations that would have caused a `MatchError` now instead will bubble up an error tuple. Most importantly, this does **not** affect the signature or behaviour of the `FunWithFlags.enabled?/2` function, which continues to return a simple boolean. ([pull/120](https://github.com/tompave/fun_with_flags/pull/120))
* Typespec improvements. These include new typespecs for previously unspecced functions, amended typespecs for the new error tuples that are now bubbled up (see previous point) and fixed typespec that incorrectly ignored a returned error tuple. ([pull/120](https://github.com/tompave/fun_with_flags/pull/120))
* The typespecs for the `FunWithFlags.Store.Persistence` Elixir behaviour have been updated (see previous point). Users of the package who implemented their own custom persistence adapters are encouraged to double-check that these respect the typespecs. ([pull/120](https://github.com/tompave/fun_with_flags/pull/120))

## v1.7.0

* Add support for Elixir 1.12. Drop support for Elixir 1.8. Elixir >= 1.9 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* Drop support for Erlang/OTP 21, and Erlang/OTP >= 22 is now required. Dropping support for older versions of Erlang/OTP simply means that this package is not tested with them in CI, and that no compatibility issues are considered bugs.
* Added support for the Erlang [dialyzer](https://erlang.org/doc/man/dialyzer.html) (via the [dialyxir](https://hex.pm/packages/dialyxir) package).
* Addressed all dialyzer warnings. Fixed some incorrect typespecs and simplified the implementation of some functions.
* Miscellaneous documentation fixes and improvements. (Thanks [kianmeng](https://github.com/kianmeng), [pull/89](https://github.com/tompave/fun_with_flags/pull/89), [pull/90](https://github.com/tompave/fun_with_flags/pull/90) and [pull/112](https://github.com/tompave/fun_with_flags/pull/112).)
* Documented the `FunWithFlags.Store.Cache` module, and its `Cache.flush/0` and `Cache.dump/0` functions. They're now part of the public API of the package.
* Introduced a new `FunWithFlags.Supervisor` module to manage the supervision tree for the package. The supervision strategy and configuration are unchanged, and host applications don't need to do anything to upgrade. However, this module is part of the public API of the package and can be used to better control the start behaviour of FunWithFlags. This has also been documented [in a new section of the readme](https://github.com/tompave/fun_with_flags#application-start-behaviour).
* Internal changes to stop using an undocumented feature of Elixir that will go away in future versions. This affects how the function to calculate Actor scores for the %-of-actors gate is invoked, but that's an internal change, so it won't affect users of the package unless they're using undocumented features. (Thanks [kelvinst](https://github.com/kelvinst), [pull/105](https://github.com/tompave/fun_with_flags/pull/105).)

## v1.6.0

* Add support for Elixir 1.11. Drop support for Elixir 1.7. Elixir >= 1.8 is now required. Dropping support for older versions of Elixir simply means that this package is no longer tested with them in CI, and that compatibility issues are not considered bugs.
* More internal changes to not compile in the package configuration. Removed compile-time references to the Ecto repo and the Ecto table name. See the release notes for v1.5.1 (below) for more details on this type of changes.
* Ecto and Postgres persistence: when updating percentage gates, use a flag-scoped advisory lock rather than locking the entire table. With the old system the entire table was locked when setting or changing any percentage gate, across all flags. With this change, the lock is scoped to one flag and the table is never fully locked.
* Dev and test fixes to support Phoenix.PubSub on OTP 23 and Elixir >= 1.10.3. This was only an issue when working locally, and there should be no problems when using the previous version of the package in a host application.
* Update Redix to 1.0. As [its changelog](https://github.com/whatyouhide/redix/blob/main/CHANGELOG.md#v100) says this doesn't introduce breaking changes, but it's a major version bump that should be documented here, as it will require changes in the host applications mix files.

## v1.5.1

* Internal changes to not compile in the persistence adapter config. This has no effect on the functionality of the package, but now the Ecto or Redis adapter configuration is not memoized anymore, and it can be changed with no need to recompile the package.

## v1.5.0

* Drop support for Elixir 1.6. Elixir >= 1.7 is now required.
* Drop support for Erlang/OTP 20, and Erlang/OTP >= 21 is now required. An older Erlang/OTP might still work with older versions of Elixir, but Elixir 1.10 requires Erlang/OTP >= 21. Dropping support for older versions of Erlang/OTP simply means that this package is not tested with them in CI, and that no compatibility issues are considered bugs.
* Upgrade Phoenix.PubSub dependency to 2.0. This provides compatibility with Phoenix 1.5.
* Typespec improvements. (Thanks [skylerparr](https://github.com/skylerparr), [pull/57](https://github.com/tompave/fun_with_flags/pull/57))
* Internal changes to how flag data is cached in the ETS table. This has no effect on the functionality of the package, with two exceptions. First, the `cache: [ttl: seconds]` config value is not memoized anymore and it can be changed without recompiling. Second, since the TTL is now stored with the ETS entries, old and new ETS data is not compatible; this is not an issue if you restart/rotate your application nodes/instances when deploying, but it will be an issue if you perform [hot code upgrades](https://hexdocs.pm/mix/1.9.4/Mix.Tasks.Release.html#module-hot-code-upgrades). In that case, you have to first empty the ETS table, for example with `FunWithFlags.Store.Cache.flush/0`.
* New config option to set a custom name for the DB table when using the Ecto persistence adapter. (Thanks [BobbyMcWho](https://github.com/BobbyMcWho), [pull/64](https://github.com/tompave/fun_with_flags/pull/64) and [pull/77](https://github.com/tompave/fun_with_flags/pull/77))

## v1.4.1

* Typespec improvements. (Thanks [LostKobrakai](https://github.com/LostKobrakai), [pull/49](https://github.com/tompave/fun_with_flags/pull/49))
* Improve Redis error handling for connection and command errors. (Thanks [chubarovNick](https://github.com/chubarovNick), [pull/54](https://github.com/tompave/fun_with_flags/pull/54))

## v1.4.0

This release focuses on making it easier to extend the package, for example with custom persistence adapters.

* Define a [behaviour](https://hexdocs.pm/elixir/typespecs.html#behaviours) in the `FunWithFlags.Store.Persistence` module that can be implemented by custom persistence adapters. The builtin Redis and Ecto adapters now formally implement this new behaviour.
* Refactor how cache-busting change notifications are published: move the logic out of the two builtin persistence adapters and into the level above them. While this is just an internal change, it narrows the responsibilities of the persistence adapters and simplifies implementing custom ones.
* Update the supervision tree to use [Elixir v1.5 style child specs](https://github.com/elixir-lang/elixir/blob/v1.5/CHANGELOG.md#streamlined-child-specs).
* Print a helpful error if a project is configured to use a persistence adapter without including its dependency packages. This mirrors what happens when the dependencies for a notifications adapter are missing.
* Document the `Flag` and `Gate` types, previously private.
* Redis persistence: relax Redix version lock to `~> 0.9`, which allows to use Redix `0.10`. It was previously locked to `~> 0.9.1` because of breaking changes in the last few Redix minor version releases, but going forward if it happens again it can be handled with a patch level release on FunWithFlags.

## v1.3.0

* Ecto persistence: added support for MySQL, via either `mariaex` or `myxql`. While both are working today, the test suite uses `myxql` because `ecto_sql` is going to deprecate the `mariaex` adapter in the future. (Thanks [stewart](https://github.com/stewart) for starting this work with [pull/41](https://github.com/tompave/fun_with_flags/pull/41) and for helping out on [pull/42](https://github.com/tompave/fun_with_flags/pull/42)).

## v1.2.1

* Fix invalid typespec that was causing compiler warnings on Elixir 1.8. (Thanks [asummers](https://github.com/asummers), [pull/34](https://github.com/tompave/fun_with_flags/pull/34))

## v1.2.0

* Redis persistence: upgrade to Redix 0.9, which deprecates Redix.PubSub. The pubsub capabilities are now part of the base Redix package. This means that FunWithFlags also needs to drop the dependency on Redix.PubSub.
* Compatibility updates in the tests for Elixir 1.8.

There is no other change in this release, but this is a minor version bump because upgrading Redix and dropping Redix.PubSub will require applications to also update their dependencies.

## v1.1.0

* Drop support for Elixir 1.5. Elixir >= 1.6 is now required.
* Drop support for OTP 19. OTP >= 20 is now required.
* Update to Ecto 3 with the `ecto_sql` package.
* Update to Redix 0.8 and Redix.PubSub 0.5.
* Ecto persistence: add `NOT NULL` constraints to the table definition in the Ecto migration. This is not a breaking change: the constraints have been added because those values are never null anyway. If users of the library want to add them, they can do so by adding [this migration](https://github.com/tompave/fun_with_flags/blob/v1.1.0/priv/ecto_repo/migrations/00000000000001_ensure_columns_are_not_null.exs) to their projects.
* Redis persistence: allow to configure the Redis URL with a system tuple to read it from an environment variable. (Thanks [seangeo](https://github.com/seangeo), [pull/29](https://github.com/tompave/fun_with_flags/pull/29))

## v1.0.0

This release introduces the last two gates that were initially planned and marks a milestone for the project. The API is now stable, and the project can graduate to `1.0.0`.

This release doesn't introduce any breaking change, however, and users of the library should be able to upgrade without problems. If you're also using [`FunWithFlags.UI`](https://github.com/tompave/fun_with_flags_ui) then make sure to also upgrade that to version `0.4.0`, which adds GUI support for the new features.

New Gates:

* Percentage of time gate
* Percentage of actors gate


## v0.11.0

* Add ability to clear the boolean gate only (useful for debugging).
* Added `FunWithFlags.get_flag/1`, to retrieve a flag struct. Useful for debugging.
* Internal improvements.

## v0.10.1

Improvements:

* Ecto persistence: explicitly set the table primary key as an integer type. This improves the compatibility with Ecto repos where primary keys default to a binary type, e.g. UUID. (Thanks [coryodaniel](https://github.com/coryodaniel), [pull/23](https://github.com/tompave/fun_with_flags/pull/23))

## v0.10.0

Possibly Breaking Changes:

* Allow binaries _and_ atoms as group gate names. Binaries are now preferred (atom group names are internally converted, stored and retrieved as binaries) and atoms are still allowed for retro-compatibility.  
While calling `FunWithFlags.enable(:foo, for_group: :bar)` is still allowed and continues to work as before, this change will impact implementations of the `FunWithFlags.Group` protocol that assume
that the group name is passed as an atom.  
To safely upgrade, these implementations should be changed to work with the group names passed as a binary instead. See the [update to the protocol implementation used in the tests](https://github.com/tompave/fun_with_flags/pull/13/files#diff-8c1bcfc3d51e8d863953ac5b57f0da2b) for an example.

Other changes:

* Compatibility updates for Ecto 2.2 (dev env, was fine in prod)

## v0.9.2

Bug Fixes:

* Fixed another issue with modules referencing Ecto.

## v0.9.1

Bug Fixes:

* Fixed an issue with module referencing Ecto that was not wrapped in a `Code.ensure_loaded?` block, which prevented the library from being used in projects that did not include Ecto.

## v0.9.0

* Ecto persistence adapter. It's now possible to store flag data with Ecto instead of Redis; if used in conjunction with the Phoenix.PubSub adapter, it's possible to use this library in Phoenix without Redis.
* The `redix` dependency is now optional.
* Added optional `ecto` dependency.

## v0.8.1

* Mark the `redix_pubsub` dependency as optional.
* Clearer error reporting for missing adapter dependencies.

## v0.8.0

New Features:

* Added support for Phoenix.PubSub as an alternative transport for the cache busting notifications.
* Added ability to enable the ETS cache but disable the cache-busting notifications, as it can be useful when running on a single node.

Other changes:

* Upgraded `redix` and `redix_pubsub` dependencies.
* Internal project and supervision changes to better support different adapters.
* Updated the Mix configuration options.
* More rational test setup.

## v0.7.1

Bug fixes:

* Resolved an issue with the PubSub connection process that would crash the entire supervision tree in case of abrupt disconnection from Redis. Ops!

## v0.7.0

New Features:

* `FunWithFlags.all_flags/0` is now public and documented.
* Added `FunWithFlags.all_flag_names/0`, public and documented.
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
