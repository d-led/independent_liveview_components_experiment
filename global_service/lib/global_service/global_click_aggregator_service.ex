defmodule GlobalService.GlobalClickAggregatorService do
  @moduledoc false
  require Logger
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_count do
    GenServer.call(__MODULE__, :get_count)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "arrivals")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "presence:lobby")
    Logger.debug("Starting GlobalClickAggregatorService")
    {:ok, %{global_clicks: 0, sent_bytes: 0, recv_bytes: 0}}
  end

  def handle_call(:get_count, _from, state) do
    {:reply, state.global_clicks, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(%{event: "click", session_id: session_id} = msg, state) do
    Logger.debug("GlobalClickAggregatorService click from session #{session_id}")
    new_clicks = state.global_clicks + 1
    Logger.debug("Total clicks: #{new_clicks}")
    sent = render_view(new_clicks)

    new_state = %{
      state
      | global_clicks: new_clicks,
        recv_bytes: state.recv_bytes + byte_size_of(msg),
        sent_bytes: state.sent_bytes + sent
    }

    {:noreply, new_state}
  end

  def handle_info(%{event: "hi", session_id: session_id} = msg, state) do
    Logger.debug("GlobalClickAggregatorService hi from session #{session_id}")
    sent = render_view(state.global_clicks)

    new_state = %{
      state
      | recv_bytes: state.recv_bytes + byte_size_of(msg),
        sent_bytes: state.sent_bytes + sent
    }

    {:noreply, new_state}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "presence:lobby",
          event: "presence_diff",
          payload: %{joins: joins}
        } = msg,
        state
      ) do
    sent =
      Enum.reduce(joins, 0, fn {session_id, _}, acc ->
        Logger.debug("trying to send a view to #{session_id}")
        acc + render_view_to_channel(state.global_clicks, "initial_renders:#{session_id}")
      end)

    new_state = %{
      state
      | recv_bytes: state.recv_bytes + byte_size_of(msg),
        sent_bytes: state.sent_bytes + sent
    }

    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    new_state = %{state | recv_bytes: state.recv_bytes + byte_size_of(msg)}
    {:noreply, new_state}
  end

  defp render_view_to_channel(count, channel) do
    broadcast_and_measure(channel, %{
      view: :global,
      count: count
    })
  end

  defp render_view(count) do
    render_view_to_channel(count, "global_rendering_topic")
  end

  defp broadcast_and_measure(channel, msg) do
    Phoenix.PubSub.broadcast(MainApp.PubSub, channel, msg)
    byte_size_of(msg)
  end

  defp byte_size_of(msg) do
    :erlang.term_to_binary(msg) |> byte_size()
  end
end
