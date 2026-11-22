defmodule Uuid58.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/nakanoasaservice/uuid58"
  @description "Shorten UUIDs to 22-character Base58 strings, and back. Order-preserving, with a stable, well-tested spec."

  def project do
    [
      app: :uuid58,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      description: @description,
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: "https://nakanoasaservice.github.io/uuid58/",
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [
      extra_applications: [:crypto]
    ]
  end

  defp package do
    [
      name: "uuid58",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Specification" => "#{@source_url}/blob/main/spec/SPEC.md",
        "Changelog" => "#{@source_url}/blob/main/elixir/CHANGELOG.md",
        "Website" => "https://nakanoasaservice.github.io/uuid58/"
      }
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "elixir/v#{@version}",
      source_url_pattern: "#{@source_url}/blob/elixir/v#{@version}/elixir/%{path}#L%{line}"
    ]
  end
end
