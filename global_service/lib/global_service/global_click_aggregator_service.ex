defmodule GlobalService.GlobalClickAggregatorService do
  require Logger
  use GenServer
  import Phoenix.HTML.Safe

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "arrivals")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "presence:lobby")
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

  def handle_info(%{event: "hi", session_id: session_id}, state) do
    Logger.debug("GlobalClickAggregatorService hi from session #{session_id}")
    render_view(state.global_clicks)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "presence:lobby",
          event: "presence_diff",
          payload: %{joins: joins}
        },
        state
      ) do
    Enum.each(joins, fn {session_id, _} ->
      Logger.debug("trying to send a view to #{session_id}")
      render_view_to_channel(state.global_clicks, "initial_renders:#{session_id}")
    end)

    {:noreply, state}
  end

  defp render_view_to_channel(count, channel) do
    assigns = %{count: count}
    rendered_global_clicks = GlobalServiceWeb.GlobalClicksView.render(assigns)
    html_string = Phoenix.HTML.safe_to_string({:safe, to_iodata(rendered_global_clicks)})

    Phoenix.PubSub.broadcast(MainApp.PubSub, channel, %{
      view: :global,
      html: html_string
    })
  end

  defp render_view(count) do
    render_view_to_channel(count, "global_rendering_topic")
  end
end
