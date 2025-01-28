defmodule MainApp.PrivateClickAggregatorService do
  require Logger
  require Phoenix.PubSub
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "presence:lobby")
    Logger.debug("Starting PrivateClickAggregatorService")
    {:ok, %{}}
  end

  def handle_info(%{event: "click", session_id: session_id}, state) do
    Logger.debug("PrivateClickAggregatorService click from session #{session_id}")
    new_state = Map.update(state, session_id, 1, &(&1 + 1))
    render_view(new_state)
    {:noreply, new_state}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "presence:lobby",
          event: "presence_diff",
          payload: %{leaves: leaves, joins: joins}
        },
        state
      ) do
    new_state =
      Enum.reduce(joins, state, fn {session_id, _}, acc ->
        Map.put_new(acc, session_id, 0)
      end)

    new_state =
      Enum.reduce(leaves, new_state, fn {session_id, _}, acc ->
        Map.delete(acc, session_id)
      end)

    Logger.debug("leaves: #{inspect(leaves)}")
    Logger.debug("joins: #{inspect(joins)}")
    Logger.debug("current: #{inspect(new_state)}")
    render_view(new_state)
    {:noreply, new_state}
  end

  def render_view(state) do
    Logger.debug("now online: #{inspect(state)}")

    Enum.each(state, fn {session_id, click_count} ->
      assigns = %{session_id: session_id, count: click_count}
      rendered_view = MainAppWeb.PrivateClickViews.render(assigns)
      Phoenix.PubSub.broadcast(MainApp.PubSub, "private_clicks:#{session_id}", %{
        view: :private,
        html: rendered_view
      })
    end)
  end
end
