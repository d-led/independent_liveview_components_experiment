defmodule PrivateServiceWeb.MainLive do
  use PrivateServiceWeb, :live_view

  def mount(_params, _session, socket) do
    sessions = 
      if connected?(socket) do
        Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
        Phoenix.PubSub.subscribe(MainApp.PubSub, "presence:lobby")
        PrivateService.PrivateClickAggregatorService.get_state()
      else
        %{}
      end

    online_sessions =
      if connected?(socket) do
        MainAppWeb.Presence.list("presence:lobby") |> Map.keys()
      else
        []
      end

    {:ok, assign(socket, sessions: sessions, online_sessions: online_sessions)}
  end

  def render(assigns) do
    ~H"""
    <div class="py-6 max-w-lg">
      <h1 class="text-2xl font-bold mb-4">Sessions Service Dashboard</h1>
      <p class="text-sm text-gray-500 mb-4">Displays session-specific click counts tracked by the Sessions Service.</p>

      <div class="bg-white border rounded p-4 mb-4">
        <h2 class="text-lg font-semibold mb-2">Sessions & Click Counts</h2>
        <%= if map_size(@sessions) == 0 do %>
          <p class="text-gray-400">No active clicks recorded yet.</p>
        <% else %>
          <ul class="divide-y divide-gray-100">
            <%= for {session_id, count} <- @sessions do %>
              <li class="py-2 flex justify-between items-center font-mono">
                <span class="text-sm text-gray-700 flex items-center gap-2">
                  <%= if session_id in @online_sessions do %>
                    <span class="h-2.5 w-2.5 rounded-full bg-green-500 inline-block" title="Online"></span>
                  <% else %>
                    <span class="h-2.5 w-2.5 rounded-full bg-gray-300 inline-block" title="Offline"></span>
                  <% end %>
                  {session_id}
                </span>
                <span class="bg-blue-100 text-blue-800 text-xs font-semibold px-2.5 py-0.5 rounded-full">{count} clicks</span>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <div class="mt-6 text-sm">
        <a href="http://localhost:4000" class="text-blue-500 hover:underline">&larr; Back to Main App</a>
      </div>
    </div>
    """
  end

  def handle_info(%{event: "click", session_id: session_id}, socket) do
    {:noreply, update(socket, :sessions, &Map.update(&1, session_id, 1, fn c -> c + 1 end))}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "presence:lobby"}, socket) do
    sessions = PrivateService.PrivateClickAggregatorService.get_state()
    online_sessions = MainAppWeb.Presence.list("presence:lobby") |> Map.keys()
    {:noreply, assign(socket, sessions: sessions, online_sessions: online_sessions)}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
