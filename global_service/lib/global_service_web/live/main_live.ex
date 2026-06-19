defmodule GlobalServiceWeb.MainLive do
  use GlobalServiceWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
      Phoenix.PubSub.subscribe(MainApp.PubSub, "global_rendering_topic")
    end

    %{global_clicks: clicks, sent_bytes: backend_sent, recv_bytes: backend_recv} =
      GlobalService.GlobalClickAggregatorService.get_state()

    {:ok,
     assign(socket,
       clicks: clicks,
       logs: [],
       backend_sent: backend_sent,
       backend_recv: backend_recv,
       ui_recv_bytes: 0
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="py-6 max-w-lg">
      <h1 class="text-2xl font-bold mb-4">Global Service Dashboard</h1>
      <p class="text-sm text-gray-500 mb-4">Displays global click counts and live logs tracked by the Global Service.</p>

      <div class="bg-gray-100 p-4 rounded mb-4">
        <p class="text-lg">Total clicks: <span class="font-bold">{@clicks}</span></p>
      </div>

      <div class="bg-gray-50 border rounded p-4 mb-4">
        <h2 class="text-lg font-semibold mb-2">Pub/Sub Traffic</h2>
        <div class="grid grid-cols-2 gap-4 text-xs font-mono text-gray-600">
          <div>
            <p class="font-bold text-gray-700 mb-1">Aggregator recv from:</p>
            <p><code>global_topic</code></p>
            <p><code>global_rendering_topic</code></p>
            <p class="mt-1">Sent: {@backend_sent} bytes</p>
            <p>Recv: {@backend_recv} bytes</p>
          </div>
          <div>
            <p class="font-bold text-gray-700 mb-1">Dashboard UI recv from:</p>
            <p><code>global_topic</code></p>
            <p><code>global_rendering_topic</code></p>
            <p class="mt-1">Recv: {@ui_recv_bytes} bytes</p>
          </div>
        </div>
      </div>
      
      <h2 class="text-lg font-semibold mb-2">Live Click Feed</h2>
      <ul class="font-mono bg-white border rounded p-2 h-48 overflow-y-auto mb-4">
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

  def handle_info(%{event: "click", session_id: session_id, timestamp: timestamp} = msg, socket) do
    bytes = :erlang.term_to_binary(msg) |> byte_size()
    {:noreply,
     socket
     |> update(:logs, &["#{timestamp}: #{session_id} clicked" | &1])
     |> update(:ui_recv_bytes, &(&1 + bytes))}
  end

  def handle_info(%{view: :global, count: count} = msg, socket) do
    bytes = :erlang.term_to_binary(msg) |> byte_size()
    %{global_clicks: ^count, sent_bytes: backend_sent, recv_bytes: backend_recv} =
      GlobalService.GlobalClickAggregatorService.get_state()
    {:noreply,
     assign(socket,
       clicks: count,
       backend_sent: backend_sent,
       backend_recv: backend_recv
     )
     |> update(:ui_recv_bytes, &(&1 + bytes))}
  end

  def handle_info(msg, socket) do
    bytes = :erlang.term_to_binary(msg) |> byte_size()
    {:noreply, update(socket, :ui_recv_bytes, &(&1 + bytes))}
  end
end
