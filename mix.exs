defmodule Alambic.Mixfile do
  use Mix.Project

  @description """
    A collection of small elixir utilities (Semaphore, CountDown, BlockingQueue).
  """

  def project do
    [app: :alambic,
     version: "1.1.0",
     description: @description,
     package: package(),
     elixir: ">= 1.6.0",
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  defp package do
    [maintainers: ["Serge Danzanvilliers"],
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
      {:earmark, ">= 1.2.0", only: :docs},
      {:ex_doc, ">= 0.14.0", only: :docs},
      {:excoveralls, ">= 0.6.3", only: :test}
    ]
  end
end
