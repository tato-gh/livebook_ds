defmodule KinoMyVegalite.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_my_vegalite,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [{:explorer, "~> 0.8"}, {:kino, "~> 0.18", override: true}, kino_vega_lite: "~> 0.1"]
  end
end
