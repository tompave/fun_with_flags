defmodule FunWithFlags.Store.Cache.Behaviour do
  @moduledoc """
  A behaviour module for implementing cache adapters.

  The package ships with a default ETS-based cache adapter (`FunWithFlags.Store.Cache`),
  but you can provide your own adapter by adopting this behaviour.

  This is useful, for example, to partition cache keys by application in an umbrella
  project where multiple OTP apps share the same `fun_with_flags` instance.

  ## Configuration

      config :fun_with_flags, :cache,
        enabled: true,
        ttl: 900,
        adapter: MyApp.CustomCache
  """

  @doc """
  Returns either a child specification if the cache adapter needs a process
  to be started and supervised, or `nil` if it does not.
  """
  @callback worker_spec() :: Supervisor.child_spec() | nil

  @doc """
  Looks up a flag by name in the cache.

  Should return:
  - `{:ok, flag}` if the flag is found and not expired.
  - `{:miss, :not_found, nil}` if the flag is not in the cache.
  - `{:miss, :expired, stale_flag}` if the flag is in the cache but expired.
  - `{:miss, :invalid, nil}` if the cached entry is invalid.
  """
  @callback get(flag_name :: atom) ::
              {:ok, FunWithFlags.Flag.t()}
              | {:miss, :not_found, nil}
              | {:miss, :expired, FunWithFlags.Flag.t()}
              | {:miss, :invalid, nil}

  @doc """
  Stores a flag in the cache.
  """
  @callback put(flag :: FunWithFlags.Flag.t()) ::
              {:ok, FunWithFlags.Flag.t()}

  @doc """
  Clears all entries from the cache.
  """
  @callback flush() :: true

  @doc """
  Returns the contents of the cache for inspection and debugging.
  """
  @callback dump() :: list()
end
