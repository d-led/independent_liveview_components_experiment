defmodule GlobalServiceWeb.MainLive do
  use GlobalServiceWeb, :live_view

  def mount(_params, _session, socket) do
    clicks =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
        Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
        GlobalService.GlobalClickAggregatorService.get_count()
      else
        0
      end

    {:ok, assign(socket, clicks: clicks, logs: [])}
  end

  def render(assigns) do
    ~H"""
    <div class="py-6 max-w-lg">
      <h1 class="text-2xl font-bold mb-4">Global Service Dashboard</h1>
      <p class="text-sm text-gray-500 mb-4">Displays global click counts and live logs tracked by the Global Service.</p>

      <div class="bg-gray-100 p-4 rounded mb-4">
        <p class="text-lg">Total clicks: <span class="font-bold">{@clicks}</span></p>
      </div>
      
      <h2 class="text-lg font-semibold mb-2">Live Click Feed</h2>
      <ul class="font-mono bg-white border rounded p-2 h-48 overflow-y-auto">
        <%= if length(@logs) == 0 do %>
          <li class="text-sm text-gray-400">Waiting for clicks...</li>
        <% else %>
          <%= for log <- @logs do %>
            <li class="text-sm text-gray-700">{log}</li>
          <% end %>
        <% end %>
      </ul>

      <div class="mt-6 text-sm">
        <a href="http://localhost:4000" class="text-blue-500 hover:underline">&larr; Back to Main App</a>
      </div>
    </div>
    """
  end

  def handle_info(%{event: "click", session_id: session_id, timestamp: timestamp}, socket) do
    {:noreply, update(socket, :logs, &["#{timestamp}: #{session_id} clicked" | &1])}
  end

  def handle_info(%{view: :global, count: count}, socket) do
    {:noreply, assign(socket, :clicks, count)}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
