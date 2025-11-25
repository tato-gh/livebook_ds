defmodule Kino.ExportToMix do
  use Kino.JS
  use Kino.JS.Live

  def new(env_file) do
    file_path = env_file |> URI.parse() |> Map.get(:path)
    livebook_node = Node.list(:connected) |> hd()
    Kino.JS.Live.new(__MODULE__, %{file_path: file_path, livebook_node: livebook_node})
  end

  @impl true
  def init(data, ctx) do
    {:ok, assign(ctx, data: data)}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{}, ctx}
  end

  @impl true
  def handle_event("export", _params, ctx) do
    data = ctx.assigns.data

    case export_to_mix(data.file_path, data.livebook_node) do
      {:ok, output_dir} ->
        relative_path = Path.relative_to_cwd(output_dir)

        broadcast_event(ctx, "result", %{
          success: true,
          message: "Successfully exported to: #{relative_path}"
        })

      {:error, reason} ->
        broadcast_event(ctx, "result", %{success: false, message: "Error: #{reason}"})
    end

    {:noreply, ctx}
  end

  defp export_to_mix(file_path, livebook_node) do
    with {:ok, content} <- File.read(file_path),
         {notebook, _} <-
           :rpc.call(livebook_node, Livebook.LiveMarkdown.Import, :notebook_from_livemd, [content]) do
      base_name = Path.basename(file_path, ".livemd")
      output_dir = Path.join(Path.dirname(file_path), base_name)
      deps_string = extract_deps_string(notebook)
      module_strings = extract_module_strings(notebook)
      generate_mix_project(output_dir, base_name, deps_string, module_strings)
      {:ok, output_dir}
    else
      error -> {:error, inspect(error)}
    end
  end

  defp extract_deps_string(notebook) do
    setup_cells =
      case notebook.setup_section do
        nil -> []
        section -> section.cells
      end

    result = extract_from_cells(setup_cells, &find_mix_install_in_source/1)
    deps_string = List.first(result) || "[]"
    filter_kino_export_to_mix(deps_string)
  end

  defp filter_kino_export_to_mix(deps_string) do
    case Code.string_to_quoted(deps_string) do
      {:ok, deps_list} when is_list(deps_list) ->
        filtered =
          Enum.reject(deps_list, fn
            {dep_name, _} when dep_name == :kino_export_to_mix -> true
            dep_name when dep_name == :kino_export_to_mix -> true
            _ -> false
          end)

        Macro.to_string(filtered)

      _ ->
        deps_string
    end
  end

  defp extract_module_strings(notebook) do
    all_cells = Enum.flat_map(notebook.sections, fn section -> section.cells end)
    extract_from_cells(all_cells, &find_defmodules_in_source/1)
  end

  defp extract_from_cells(cells, extractor_fn) do
    cells
    |> Enum.filter(&elixir_code_cell?/1)
    |> Enum.flat_map(fn cell ->
      case Code.string_to_quoted(cell.source) do
        {:ok, ast} -> extractor_fn.(ast)
        _ -> []
      end
    end)
  end

  defp elixir_code_cell?(%{__struct__: Livebook.Notebook.Cell.Code, language: :elixir}) do
    true
  end

  defp elixir_code_cell?(_) do
    false
  end

  defp find_mix_install_in_source(ast) do
    find_in_ast(ast, fn
      {{:., _, [{:__aliases__, _, [:Mix]}, :install]}, _, [deps_list | _]} ->
        {:match, Macro.to_string(deps_list)}

      _ ->
        :no_match
    end)
  end

  defp find_defmodules_in_source(ast) do
    find_in_ast(ast, fn
      {:defmodule, _, _} = node -> {:match, Macro.to_string(node)}
      _ -> :no_match
    end)
  end

  defp find_in_ast(ast, matcher_fn) do
    case ast do
      {:__block__, _, expressions} ->
        Enum.flat_map(expressions, &find_in_ast(&1, matcher_fn))

      node ->
        case matcher_fn.(node) do
          {:match, result} -> [result]
          :no_match -> []
        end
    end
  end

  defp generate_mix_project(output_dir, base_name, deps_string, module_strings) do
    lib_dir = Path.join(output_dir, "lib")
    File.mkdir_p!(lib_dir)
    app_name_str = base_name |> String.replace("-", "_")
    app_name = String.to_atom(app_name_str)
    module_name = Macro.camelize(app_name_str)
    mix_exs_content = "defmodule #{module_name}.MixProject do
  use Mix.Project

  def project do
    [
      app: #{inspect(app_name)},
      version: \"0.1.0\",
      elixir: \"~> 1.18\",
      deps: deps()
    ]
  end

  defp deps do
    #{deps_string}
  end
end
"
    File.write!(Path.join(output_dir, "mix.exs"), mix_exs_content)
    lib_file_path = Path.join(lib_dir, "#{base_name}.ex")
    lib_content = Enum.join(module_strings, "\n\n")
    File.write!(lib_file_path, lib_content)
    :ok
  end

  asset("main.js") do
    "export function init(ctx, data) {\n  ctx.importCSS(\"main.css\");\n\n  ctx.root.innerHTML = `\n    <div class=\"export-container\">\n      <button id=\"export-btn\" class=\"export-btn\">\n        📦 Export to Mix Project\n      </button>\n      <div id=\"result\" class=\"result-message\"></div>\n    </div>\n  `;\n\n  const btn = ctx.root.querySelector(\"#export-btn\");\n  const resultDiv = ctx.root.querySelector(\"#result\");\n\n  btn.addEventListener(\"click\", () => {\n    btn.disabled = true;\n    btn.textContent = \"⏳ Exporting...\";\n    ctx.pushEvent(\"export\", {});\n  });\n\n  ctx.handleEvent(\"result\", ({ success, message }) => {\n    btn.disabled = false;\n    btn.textContent = \"📦 Export to Mix Project\";\n\n    resultDiv.style.display = \"block\";\n    resultDiv.className = success ? \"result-message success\" : \"result-message error\";\n    resultDiv.textContent = (success ? \"✅ \" : \"❌ \") + message;\n  });\n}\n"
  end

  asset("main.css") do
    ".export-container {\n  padding: 16px;\n  background: #f5f5f5;\n  border-radius: 8px;\n}\n\n.export-btn {\n  padding: 10px 20px;\n  background: #2196F3;\n  color: white;\n  border: none;\n  border-radius: 4px;\n  cursor: pointer;\n  font-size: 14px;\n}\n\n.result-message {\n  margin-top: 12px;\n  padding: 8px;\n  display: none;\n  border-radius: 4px;\n}\n\n.result-message.success {\n  background: #c8e6c9;\n  color: #2e7d32;\n}\n\n.result-message.error {\n  background: #ffcdd2;\n  color: #c62828;\n}\n"
  end
end