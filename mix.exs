defmodule Sansa.MixProject do
  use Mix.Project

  def project do
    [
      app: :sansa,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Sansa, []},
      extra_applications: [:logger, :logger_file_backend]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.0", override: true},
      {:logger_file_backend, "~> 0.0.10"},
      {:timex, "~> 3.5"},
      {:random_forest, git: "https://github.com/gregoire-riviere/random_forest_ex", branch: "main", app: false}
    ]
  end
end
