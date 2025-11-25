defmodule KinoExportToMix.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_export_to_mix,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [kino: "~> 0.14.0"]
  end
end
