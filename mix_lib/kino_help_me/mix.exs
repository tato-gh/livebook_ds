defmodule KinoHelpMe.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_help_me,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [kino: "~> 0.14.0", req: "~> 0.5.0", jason: "~> 1.4"]
  end
end
