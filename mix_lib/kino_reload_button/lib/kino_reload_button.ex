defmodule Kino.ReloadButton do
  use Kino.JS
  use Kino.JS.Live

  def new(env_file) do
    file_path = env_file |> URI.parse() |> Map.get(:path)
    livebook_node = get_livebook_node()
    Kino.JS.Live.new(__MODULE__, %{file_path: file_path, livebook_node: livebook_node})
  end

  defp get_livebook_node do
    Node.list(:connected)
    |> Enum.find(fn node ->
      node_str = Atom.to_string(node)
      not String.contains?(node_str, "--")
    end)
  end

  defp get_session_id(livebook_node, file_path) do
    livebook_node
    |> :rpc.call(Livebook.Sessions, :list_sessions, [])
    |> Enum.find(&(&1.file && &1.file.path == file_path))
    |> Map.get(:id)
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
  def handle_event("reload", _params, ctx) do
    data = ctx.assigns.data
    session_id = get_session_id(data.livebook_node, data.file_path)
    {:ok, content} = File.read(data.file_path)

    {notebook, _} =
      :rpc.call(data.livebook_node, Livebook.LiveMarkdown, :notebook_from_livemd, [content])

    {:ok, new_session} =
      :rpc.call(data.livebook_node, Livebook.Sessions, :create_session, [
        [notebook: notebook, mode: :default]
      ])

    code = "spawn(fn ->
  Process.sleep(1000)
  {:ok, old_session} = Livebook.Sessions.fetch_session(\"#{session_id}\")
  Livebook.Session.close(old_session.pid)
  {:ok, new_session} = Livebook.Sessions.fetch_session(\"#{new_session.id}\")
  file = Livebook.FileSystem.File.local(\"#{data.file_path}\")
  Livebook.Session.set_file(new_session.pid, file)
end)
"
    :rpc.call(data.livebook_node, Code, :eval_string, [code])
    broadcast_event(ctx, "navigate", %{url: "/sessions/#{new_session.id}"})
    {:noreply, ctx}
  end

  asset("main.js") do
    "export function init(ctx, data) {\n  ctx.root.innerHTML = `\n    <div style=\"padding: 16px; background: #f5f5f5; border-radius: 8px;\">\n      <button id=\"reload-btn\" style=\"padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px;\">\n        🔄 Reload Notebook\n      </button>\n    </div>\n  `;\n\n  const btn = ctx.root.querySelector(\"#reload-btn\");\n  btn.addEventListener(\"click\", () => {\n    ctx.pushEvent(\"reload\", {});\n  });\n\n  ctx.handleEvent(\"navigate\", ({ url }) => {\n    window.top.location.href = url;\n  });\n}\n"
  end
end