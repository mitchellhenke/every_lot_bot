defmodule EveryLotBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :every_lot_bot,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.14.0"},
      {:extwitter, ">= 0.0.0"},
      {:tesla, ">= 0.0.0"},
      {:tzdata, "~> 1.1"},
      {:nimble_csv, "~> 1.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
