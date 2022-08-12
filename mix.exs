defmodule FunWithFlags.Mixfile do
  use Mix.Project

  @source_url "https://github.com/tompave/fun_with_flags"
  @version "1.9.0"

  def project do
    [
      app: :fun_with_flags,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer(),
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: extra_applications(Mix.env),
     mod: {FunWithFlags.Application, []}]
  end

  defp extra_applications(:test), do: local_extra_applications()
  defp extra_applications(:dev),  do: local_extra_applications()
  defp extra_applications(_),     do: [:logger]

  # When working locally with the Ecto adapter, start the ecto_sql
  # and postgrex applications. They're not started automatically
  # because they're optional, I think.
  #
  # Also start the Phoenix PubSub application if that notification
  # adapter is configured.
  #
  defp local_extra_applications do
    apps =
      if System.get_env("PERSISTENCE") == "ecto" do
        [:logger, :ecto, :ecto_sql, :postgrex]
      else
        [:logger, :redix]
      end

    apps =
      if System.get_env("PUBSUB_BROKER") == "phoenix_pubsub" do
        [:phoenix_pubsub | apps]
      else
        apps
      end

    apps
  end

  defp deps do
    [
      {:redix, "~> 1.0", optional: true},
      {:ecto_sql, "~> 3.0", optional: true},
      {:postgrex, "~> 0.16", optional: true, only: [:dev, :test]},
      {:myxql, "~> 0.2", optional: true, only: [:dev, :test]},
      {:phoenix_pubsub, "~> 2.0", optional: true},

      {:mock, "~> 0.3", only: :test},

      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer do
    [
      # Add optional dependencies to avoid "unknown_function" warnings.
      plt_add_apps: [:redix, :ecto, :ecto_sql, :phoenix_pubsub],
    ]
  end

  defp aliases do
    [
      {:"test.all", [&run_all_tests/1]},
      {:"test.phx", [&run_tests__redis_pers__phoenix_pubsub/1]},
      {:"test.ecto.postgres", [&run_tests__ecto_pers_postgres__phoenix_pubsub/1]},
      {:"test.ecto.mysql", [&run_tests__ecto_pers_mysql__phoenix_pubsub/1]},
      {:"test.redis", [&run_tests__redis_pers__redis_pubsub/1]},
    ]
  end

  # Runs all the test configurations.
  # If any fails, exit with status code 1, so that this can properly fail in CI.
  #
  defp run_all_tests(arg) do
    tests = [
      &run_tests__redis_pers__redis_pubsub/1, &run_integration_tests__redis_pers__redis_pubsub__no_cache/1,
      &run_tests__redis_pers__phoenix_pubsub/1, &run_integration_tests__redis_pers__phoenix_pubsub__no_cache/1,
      &run_tests__ecto_pers_postgres__phoenix_pubsub/1, &run_integration_tests__ecto_pers_postgres__phoenix_pubsub__no_cache/1,
      &run_tests__ecto_pers_mysql__phoenix_pubsub/1, &run_integration_tests__ecto_pers_mysql__phoenix_pubsub__no_cache/1,
    ]

    exit_codes = case System.get_env("CI") do
      "true" ->
        tests |> Enum.map(fn test_fn -> _run_test_with_retries(3, 500, fn -> test_fn.(arg) end) end)
      _ ->
        tests |> Enum.map(fn test_fn -> test_fn.(arg) end)
    end

    if Enum.any?(exit_codes, &(&1 != 0)) do
      require Logger
      Logger.error("Some test configuration did not pass.")
      exit({:shutdown, 1})
    end
  end

  # Because some tests are flaky in CI.
  #
  defp _run_test_with_retries(attempts, sleep_ms, test_fn) when attempts > 0 do
    IO.puts("---\nRunning a test task with retries. Attempts left: #{attempts}, sleep ms: #{sleep_ms}.\n---")
    case test_fn.() do
      0 -> 0 # Successful run, simply return the status.
      _ ->
        :timer.sleep(sleep_ms)
        remaining = attempts - 1
        IO.puts("Test failed. Retries left: #{remaining}.")
        _run_test_with_retries(remaining, sleep_ms, test_fn)
    end
  end

  defp _run_test_with_retries(_, _, _) do
    IO.puts("---\nAll retries failed. Returning exit code 1.\n---")
    1
  end

  # Run the tests with Redis as persistent store and Redis PubSub as broker.
  #
  # Cache enabled, force re-compilation.
  #
  defp run_tests__redis_pers__redis_pubsub(arg) do
    Mix.shell.cmd(
      "mix test --color --force --exclude phoenix_pubsub --exclude ecto_persistence #{arg}",
      env: [
        {"CACHE_ENABLED", "true"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Redis as persistent store and Redis PubSub as broker.
  #
  defp run_integration_tests__redis_pers__redis_pubsub__no_cache(arg) do
    Mix.shell.cmd(
      "mix test --color --force --only integration #{arg}",
      env: [
        {"CACHE_ENABLED", "false"},
      ]
    )
  end

  # Run the tests with Redis as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests__redis_pers__phoenix_pubsub(arg) do
    Mix.shell.cmd(
      "mix test --color --force --exclude redis_pubsub --exclude ecto_persistence #{arg}",
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Redis as persistent store and Phoenix.PubSubas broker.
  #
  defp run_integration_tests__redis_pers__phoenix_pubsub__no_cache(arg) do
    Mix.shell.cmd(
      "mix test --color --force --only integration #{arg}",
      env: [
        {"CACHE_ENABLED", "false"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
      ]
    )
  end

  # Run the tests with Ecto+PostgreSQL as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests__ecto_pers_postgres__phoenix_pubsub(arg) do
    Mix.shell.cmd(
      "mix test --color --force --exclude redis_pubsub --exclude redis_persistence #{arg}",
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
        {"PERSISTENCE", "ecto"},
        {"RDBMS", "postgres"},
      ]
    )
  end

  # Run the tests with Ecto+MySQL as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests__ecto_pers_mysql__phoenix_pubsub(arg) do
    Mix.shell.cmd(
      "mix test --color --force --exclude redis_pubsub --exclude redis_persistence #{arg}",
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
        {"PERSISTENCE", "ecto"},
        {"RDBMS", "mysql"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Ecto+PostgreSQL as persistent store and Phoenix.PubSub as broker.
  #
  defp run_integration_tests__ecto_pers_postgres__phoenix_pubsub__no_cache(arg) do
    Mix.shell.cmd(
      "mix test --color --force --only integration #{arg}",
      env: [
        {"CACHE_ENABLED", "false"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
        {"PERSISTENCE", "ecto"},
        {"RDBMS", "postgres"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Ecto+MySQL as persistent store and Phoenix.PubSub as broker.
  #
  defp run_integration_tests__ecto_pers_mysql__phoenix_pubsub__no_cache(arg) do
    Mix.shell.cmd(
      "mix test --color --force --only integration #{arg}",
      env: [
        {"CACHE_ENABLED", "false"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
        {"PERSISTENCE", "ecto"},
        {"RDBMS", "mysql"},
      ]
    )
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "dev_support"]
  defp elixirc_paths(:dev), do: ["lib", "dev_support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp description do
    """
    FunWithFlags, a flexible and fast feature toggle library for Elixir.
    """
  end

  defp package do
    [
      maintainers: [
        "Tommaso Pavese"
      ],
      licenses: [
        "MIT"
      ],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "FunWithFlags",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
