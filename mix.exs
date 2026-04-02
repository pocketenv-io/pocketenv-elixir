defmodule Pocketenv.MixProject do
  use Mix.Project

  def project do
    [
      app: :pocketenv_ex,
      version: "0.1.6",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir SDK for the Pocketenv",
      package: package(),
      docs: docs(),
      source_url: "https://github.com/pocketenv-io/pocketenv-elixir",
      homepage_url: "https://github.com/pocketenv-io/pocketenv-elixir"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:kcl, "~> 0.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/pocketenv-io/pocketenv-elixir"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
