defmodule KinoDataInput.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_data_input,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [kino: "~> 0.14", explorer: "~> 0.11.1"]
  end
end
