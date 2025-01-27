defmodule MainAppWeb.MainLive do
  use MainAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
      MainAppWeb.Presence.track(self(), "presence:lobby", id_of(socket), %{})
    end

    {:ok, assign(socket, click_logs: [], rendered_global_clicks: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 w-full h-full">
      <div class="col-span-1 w-full">
        <button
          phx-click="click"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Click me!
        </button>
      </div>
      <div class="col-span-1 w-full">
        2
      </div>
      <div class="col-span-1 w-full h-full">
        <ul class="font-mono">
          <%= for log <- @click_logs do %>
            <li>{log}</li>
          <% end %>
        </ul>
      </div>
      <div class="col-span-1 w-full h-full">
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

  def handle_info(%{html: rendered_global_clicks}, socket) do
    {:noreply, assign(socket, :rendered_global_clicks, rendered_global_clicks)}
  end

  defp id_of(%{id: id}) do
    id |> String.trim_leading("phx-")
  end
end
