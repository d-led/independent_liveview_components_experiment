defmodule MainApp.GlobalClickAggregatorService do
  require Logger
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
    Logger.debug("Starting GlobalClickAggregatorService")
    {:ok, %{global_clicks: 0}}
  end

  def handle_info(%{event: "click", session_id: session_id}, state) do
    Logger.debug("GlobalClickAggregatorService click from session #{session_id}")
    new_state = %{state | global_clicks: state.global_clicks + 1}
    Logger.debug("Total clicks: #{new_state.global_clicks}")
    render_view(new_state.global_clicks)
    {:noreply, new_state}
  end

  defp render_view(count) do
    assigns = %{count: count}
    rendered_global_clicks = MainAppWeb.GlobalClicksView.render(assigns)

    Phoenix.PubSub.broadcast(MainApp.PubSub, "global_rendering_topic", %{
      html: rendered_global_clicks
    })
  end
end
