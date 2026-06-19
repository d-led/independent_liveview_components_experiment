defmodule MainAppWeb.MainLive do
  use MainAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "private_clicks:#{id_of(socket)}")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "initial_renders:#{id_of(socket)}")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "modules:new:local")
      MainAppWeb.Presence.track(self(), "presence:lobby", id_of(socket), %{})
      Phoenix.PubSub.broadcast(MainApp.PubSub, "arrivals", %{
        event: "hi",
        session_id: id_of(socket),
        timestamp: timestamp()
      })
    end

    {:ok,
     assign(socket,
       click_logs: [],
       global_clicks_count: nil,
       private_clicks_count: nil,
       session_id: id_of(socket),
       nodes_in_cluster: 0
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Local Interaction</div>
        <button
          phx-click="click"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Click me!
        </button>
      </div>
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Sessions Service</div>
        <%= if Code.ensure_loaded?(PrivateServiceWeb.PrivateClickViews) and @private_clicks_count do %>
          {apply(PrivateServiceWeb.PrivateClickViews, :render, [%{count: @private_clicks_count, session_id: @session_id}])}
        <% else %>
          <p class="text-gray-400">Waiting for Sessions service component...</p>
        <% end %>
      </div>
      <div class="col-span-1 w-full h-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Local</div>
        <div>
          <h1>Cluster</h1>
          <p>Node name: <%= Node.self() %></p>
          <p :if={@nodes_in_cluster > 0}>Nodes in cluster: {@nodes_in_cluster + 1}</p>
        </div>
        <h1 :if={length(@click_logs) > 0}>Log</h1>
        <ul class="font-mono">
          <%= for log <- @click_logs do %>
            <li>{log}</li>
          <% end %>
        </ul>
      </div>
      <div class="col-span-1 w-full h-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Global Service</div>
        <%= if Code.ensure_loaded?(GlobalServiceWeb.GlobalClicksView) and @global_clicks_count do %>
          {apply(GlobalServiceWeb.GlobalClicksView, :render, [%{count: @global_clicks_count}])}
        <% else %>
          <p class="text-gray-400">Waiting for Global service component...</p>
        <% end %>
      </div>
      <div class="col-span-2 mt-4 pt-4 border-t border-gray-200 text-sm text-gray-500 flex gap-4">
        <span class="font-semibold">Other UIs:</span>
        <a href="http://localhost:4001" target="_blank" class="text-blue-500 hover:underline">Global Service (:4001)</a>
        <span>|</span>
        <a href="http://localhost:4002" target="_blank" class="text-blue-500 hover:underline">Sessions Service (:4002)</a>
      </div>
    </div>
    """
  end

  def handle_event("click", _params, socket) do
    session_id = id_of(socket)

    Phoenix.PubSub.broadcast(MainApp.PubSub, "global_topic", %{
      event: "click",
      session_id: session_id,
      timestamp: timestamp()
    })

    {:noreply, socket}
  end

  def handle_info(%{event: "click", session_id: session_id, timestamp: timestamp}, socket) do
    click_logs = ["#{timestamp}: #{session_id} clicked" | socket.assigns.click_logs]
    {:noreply, assign(socket, :click_logs, click_logs) |> update_cluster_size()}
  end

  def handle_info(%{view: :global, count: count}, socket) do
    {:noreply, assign(socket, :global_clicks_count, count) |> update_cluster_size()}
  end

  def handle_info(%{view: :private, count: count}, socket) do
    {:noreply, assign(socket, :private_clicks_count, count) |> update_cluster_size()}
  end

  def handle_info({:new_module_local, _mod}, socket) do
    {:noreply, update_cluster_size(socket)}
  end

  defp id_of(%{id: id}) do
    id |> String.trim_leading("phx-")
  end

  defp update_cluster_size(socket) do
    nodes_in_cluster = length(Node.list())
    assign(socket, :nodes_in_cluster, nodes_in_cluster)
  end

  defp timestamp() do
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()
      |> String.trim_trailing("Z")
  end
end
