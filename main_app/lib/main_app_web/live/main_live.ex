defmodule MainAppWeb.MainLive do
  use MainAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "private_clicks:#{id_of(socket)}")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "initial_renders:#{id_of(socket)}")
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
       rendered_global_clicks: nil,
       private_clicks: nil,
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
        <div class="absolute -top-3 left-4 bg-white px-1">Private</div>
        <%= if @private_clicks do %>
          <%= Phoenix.HTML.raw(@private_clicks) %>
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
        <div class="absolute -top-3 left-4 bg-white px-1">Global</div>
        <%= if @rendered_global_clicks do %>
          <%= Phoenix.HTML.raw(@rendered_global_clicks) %>
        <% end %>
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

  def handle_info(%{view: :global, html: html}, socket) do
    {:noreply, assign(socket, :rendered_global_clicks, html) |> update_cluster_size()}
  end

  def handle_info(%{view: :private, html: html}, socket) do
    {:noreply, assign(socket, :private_clicks, html) |> update_cluster_size()}
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
