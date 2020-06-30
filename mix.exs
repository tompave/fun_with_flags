defmodule FunWithFlags.Mixfile do
  use Mix.Project

  @version "1.5.1"

  def project do
    [
      app: :fun_with_flags,
      source_url: "https://github.com/tompave/fun_with_flags",
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
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

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev},
      {:mock, "~> 0.3", only: :test},

      {:redix, "~> 0.9", optional: true},
      {:ecto_sql, "~> 3.0", optional: true},
      {:postgrex, "~> 0.13", optional: true, only: [:dev, :test]},
      {:myxql, "~> 0.2", optional: true, only: [:dev, :test]},

      {:phoenix_pubsub, "~> 2.0", optional: true},

      {:credo, "~> 1.4", only: :dev, runtime: false},
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

    exit_codes = tests |> Enum.map(fn(test_fn) -> test_fn.(arg) end)

    if Enum.any?(exit_codes, &(&1 != 0)) do
      require Logger
      Logger.error("Some test configuration did not pass.")
      exit({:shutdown, 1})
    end
  end


  # Run the tests with Redis as persistent store and Redis PubSub as broker.
  #
  # Cache enabled, force re-compilation.
  #
  defp run_tests__redis_pers__redis_pubsub(_) do
    Mix.shell.cmd(
      "mix test --color --force --exclude phoenix_pubsub --exclude ecto_persistence", 
      env: [
        {"CACHE_ENABLED", "true"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Redis as persistent store and Redis PubSub as broker.
  #
  defp run_integration_tests__redis_pers__redis_pubsub__no_cache(_) do
    Mix.shell.cmd(
      "mix test --color --force --only integration",
      env: [
        {"CACHE_ENABLED", "false"},
      ]
    )
  end

  # Run the tests with Redis as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests__redis_pers__phoenix_pubsub(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --exclude redis_pubsub --exclude ecto_persistence --exclude phoenix_pubsub:with_ecto --include phoenix_pubsub:with_redis --include phoenix_pubsub:true", 
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
      ]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, Redis as persistent store and Phoenix.PubSubas broker.
  #
  defp run_integration_tests__redis_pers__phoenix_pubsub__no_cache(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --only integration",
      env: [
        {"CACHE_ENABLED", "false"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
      ]
    )
  end

  # Run the tests with Ecto+PostgreSQL as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests__ecto_pers_postgres__phoenix_pubsub(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --exclude redis_pubsub --exclude redis_persistence --exclude phoenix_pubsub:with_redis --include phoenix_pubsub:with_ecto --include phoenix_pubsub:true --include ecto_persistence", 
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
  defp run_tests__ecto_pers_mysql__phoenix_pubsub(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --exclude redis_pubsub --exclude redis_persistence --exclude phoenix_pubsub:with_redis --include phoenix_pubsub:with_ecto --include phoenix_pubsub:true --include ecto_persistence", 
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
  defp run_integration_tests__ecto_pers_postgres__phoenix_pubsub__no_cache(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --only integration",
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
  defp run_integration_tests__ecto_pers_mysql__phoenix_pubsub__no_cache(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --only integration",
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
        "GitHub" => "https://github.com/tompave/fun_with_flags",
        "Changelog" => "https://github.com/tompave/fun_with_flags/blob/master/CHANGELOG.md"
      }
    ]
  end


  defp docs do
    [
      extras: ["README.md"],
      main: "FunWithFlags",
      source_url: "https://github.com/tompave/fun_with_flags/",
      source_ref: "v#{@version}"
    ]
  end
end
