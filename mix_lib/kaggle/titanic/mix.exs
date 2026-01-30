defmodule Titanic.MixProject do
  use Mix.Project

  def project do
    [
      app: :titanic,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [explorer: "~> 0.8", kino: "~> 0.14"]
  end
end
