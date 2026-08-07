defmodule BubblesNotifications.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/fishonfire/bubbles_notifications"

  def project do
    [
      app: :bubbles_notifications,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp description do
    "BubblesNotifications client for the Bubbles Push Notifications API."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Source" => @source_url,
        "Docs" => "https://hexdocs.pm/bubbles_notifications"
      },
      maintainers: ["Fish on Fire"],
      files: ["lib", "mix.exs", "README.md", "LICENSE", ".formatter.exs"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
