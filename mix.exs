defmodule GlobalId.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_id,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bmark, "~> 1.0.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
