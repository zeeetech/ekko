defmodule Ekko.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ekko,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: [plt_add_apps: [:public_key, :crypto]],
      description: "Elixir SDK for building Amazon Alexa custom skills",
      source_url: "https://github.com/zeeetech-br/ekko",
      homepage_url: "https://github.com/zeeetech-br/ekko",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :public_key, :crypto, :inets, :ssl],
      mod: {Ekko.Application, []}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/zeeetech-br/ekko"},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/audio-player.md",
        "guides/request-verification.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        Core: [Ekko, Ekko.Skill, Ekko.Request],
        "Request Types": ~r/Ekko\.Request\..*/,
        AudioPlayer: ~r/Ekko\.AudioPlayer.*/,
        Transport: [Ekko.Plug, Ekko.Verifier, Ekko.Verifier.Default, Ekko.Verifier.NoOp],
        "Crypto (Internal)": ~r/Ekko\.Crypto\..*/,
        Testing: [Ekko.Test.RequestFixtures]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:finch, "~> 0.18"},
      {:mox, "~> 1.2", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:stream_data, "~> 1.0", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
