defmodule FunWithFlags.Mixfile do
  use Mix.Project

  @version "0.4.0"

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
    [extra_applications: [:logger],
     mod: {FunWithFlags.Application, []}]
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
      {:mock, "~> 0.2.1", only: [:test, :test_no_cache]},
      {:redix, "~> 0.5.1"},
      {:redix_pubsub, "~> 0.2.0"},
    ]
  end


  defp aliases do
    [
      {:"test.all", [&run_tests/1, &run_integration_tests/1]}
    ]
  end


  # Runs the normal test suite
  #
  defp run_tests(_) do
    Mix.shell.cmd(
      "mix test --color", 
      env: [{"MIX_ENV", "test"}]
    )
  end

  # Re-run integration tests with the _other_
  # test ENV, where the cache is disabled.
  #
  defp run_integration_tests(_) do
    IO.puts "\nRepeating integration tests with the Cache disabled."
    Mix.shell.cmd(
      "mix test test/fun_with_flags_test.exs --color",
      env: [{"MIX_ENV", "test_no_cache"}]
    )
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:test_no_cache), do: ["lib", "test/support"]
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
