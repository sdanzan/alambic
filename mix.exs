defmodule Alambic.Mixfile do
  use Mix.Project

  @description """
    A collection of small elixir utilities (Semaphore, CountDown).
  """

  def project do
    [app: :alambic,
     version: "0.0.1",
     description: @description,
     package: package,
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  defp package do
    [maintainers: ["Serge Danzanvilliers <serge.danzanvilliers@gmail.com>"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/sdanzan/alambic"}]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:earmark, "~> 0.1.17", only: :docs},
      {:ex_doc, "~> 0.10.0", only: :docs},
    ]
  end
end
