defmodule FunWithFlags.Mixfile do
  use Mix.Project

  @version "0.8.1"

  def project do
    [
      app: :fun_with_flags,
      source_url: "https://github.com/tompave/fun_with_flags",
      version: @version,
      elixir: "~> 1.4",
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

  # When working locally with the Ecto adapter, start the postgrex
  # application. It's not started automatically because it's
  # optional, I think.
  #
  defp local_extra_applications do
    if System.get_env("PERSISTENCE") == "ecto" do
      [:logger, :postgrex]
    else
      [:logger]
    end
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
      {:ex_doc, "~> 0.15", only: :dev},
      {:mock, "~> 0.2.1", only: :test},
      {:redix, "~> 0.6.1"},
      {:redix_pubsub, "~> 0.4.1", optional: true},
      {:phoenix_pubsub, "~> 1.0", optional: true},
      {:ecto, "~> 2.1", optional: true},
      {:postgrex, "~> 0.13", optional: true, only: [:dev, :test]},
    ]
  end


  defp aliases do
    [
      {:"test.all", [&run_tests/1, &run_integration_tests_no_cache/1, &run_tests_phoenix_pubsub/1]},
      {:"test.phx", [&run_tests_phoenix_pubsub/1]},
      {:"test.ecto", [&run_tests_ecto_persistence/1]},
    ]
  end


  # Runs the entire test suite.
  # Cache enabled, force re-compilation.
  #
  defp run_tests(_) do
    Mix.shell.cmd(
      "mix test --color --force", 
      env: [{"CACHE_ENABLED", "true"}]
    )
  end

  # Runs the integration tests only.
  # Cache disabled, force re-compilation.
  #
  defp run_integration_tests_no_cache(_) do
    Mix.shell.cmd(
      "mix test --color --force --only integration",
      env: [{"CACHE_ENABLED", "false"}]
    )
  end

  # PUBSUB_BROKER=phoenix_pubsub iex -S mix test --force --no-start --exclude redis_pubsub --include phoenix_pubsub
  #
  defp run_tests_phoenix_pubsub(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --exclude redis_pubsub --include phoenix_pubsub", 
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
      ]
    )
  end

  # Run the tests with Ecto as persistent store and Phoenix.PubSub as broker.
  #
  defp run_tests_ecto_persistence(_) do
    Mix.shell.cmd(
      "mix test --color --force --no-start --exclude redis_pubsub --exclude redis_persistence --include phoenix_pubsub --include ecto_persistence", 
      env: [
        {"CACHE_ENABLED", "true"},
        {"PUBSUB_BROKER", "phoenix_pubsub"},
        {"PERSISTENCE", "ecto"}
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
