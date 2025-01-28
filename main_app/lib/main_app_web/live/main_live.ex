defmodule MainAppWeb.MainLive do
  use MainAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "private_clicks:#{id_of(socket)}")
      MainAppWeb.Presence.track(self(), "presence:lobby", id_of(socket), %{})
    end

    {:ok, assign(socket, click_logs: [], rendered_global_clicks: nil, private_clicks: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Interaction</div>
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
          {@private_clicks}
        <% end %>
      </div>
      <div class="col-span-1 w-full h-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">All clicks</div>
        <ul class="font-mono">
          <%= for log <- @click_logs do %>
            <li>{log}</li>
          <% end %>
        </ul>
      </div>
      <div class="col-span-1 w-full h-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Public</div>
        <%= if @rendered_global_clicks do %>
          {@rendered_global_clicks}
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("click", _params, socket) do
    session_id = id_of(socket)

    timestamp =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()
      |> String.trim_trailing("Z")

    Phoenix.PubSub.broadcast(MainApp.PubSub, "global_topic", %{
      event: "click",
      session_id: session_id,
      timestamp: timestamp
    })

    {:noreply, socket}
  end

  def handle_info(%{event: "click", session_id: session_id, timestamp: timestamp}, socket) do
    click_logs = ["#{timestamp}: #{session_id} clicked" | socket.assigns.click_logs]
    {:noreply, assign(socket, :click_logs, click_logs)}
  end

  def handle_info(%{view: :global, html: html}, socket) do
    {:noreply, assign(socket, :rendered_global_clicks, html)}
  end

  def handle_info(%{view: :private, html: html}, socket) do
    {:noreply, assign(socket, :private_clicks, html)}
  end

  defp id_of(%{id: id}) do
    id |> String.trim_leading("phx-")
  end
end
