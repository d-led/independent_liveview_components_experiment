defmodule PrivateService.PrivateClickAggregatorService do
  @moduledoc false
  require Logger
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def init(_) do
    Phoenix.PubSub.subscribe(MainApp.PubSub, "global_topic")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "arrivals")
    Phoenix.PubSub.subscribe(MainApp.PubSub, "presence:lobby")
    Logger.debug("Starting PrivateClickAggregatorService")
    {:ok, %{sessions: %{}, sent_bytes: 0, recv_bytes: 0}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(%{event: "click", session_id: session_id} = msg, state) do
    Logger.debug("PrivateClickAggregatorService click from session #{session_id}")
    new_sessions = Map.update(state.sessions, session_id, 1, &(&1 + 1))
    sent = render_view(new_sessions)

    new_state = %{
      state
      | sessions: new_sessions,
        recv_bytes: state.recv_bytes + byte_size_of(msg),
        sent_bytes: state.sent_bytes + sent
    }

    {:noreply, new_state}
  end

  def handle_info(%{event: "hi", session_id: session_id} = msg, state) do
    Logger.debug("PrivateClickAggregatorService hi from session #{session_id}")
    click_count = Map.get(state.sessions, session_id, 0)
    sent = render_one(session_id, click_count)

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
          payload: %{leaves: leaves, joins: joins}
        } = msg,
        state
      ) do
    new_sessions =
      Enum.reduce(joins, state.sessions, fn {session_id, _}, acc ->
        Map.put_new(acc, session_id, 0)
      end)

    Logger.debug("leaves: #{inspect(leaves)}")
    Logger.debug("joins: #{inspect(joins)}")
    Logger.debug("current: #{inspect(new_sessions)}")
    sent = render_view(new_sessions)

    new_state = %{
      state
      | sessions: new_sessions,
        recv_bytes: state.recv_bytes + byte_size_of(msg),
        sent_bytes: state.sent_bytes + sent
    }

    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    new_state = %{state | recv_bytes: state.recv_bytes + byte_size_of(msg)}
    {:noreply, new_state}
  end

  defp render_view(sessions) do
    Enum.reduce(sessions, 0, fn {session_id, click_count}, acc ->
      acc + render_one(session_id, click_count)
    end)
  end

  defp render_one(session_id, click_count) do
    broadcast_and_measure("private_clicks:#{session_id}", %{
      view: :private,
      count: click_count
    })
  end

  defp broadcast_and_measure(topic, msg) do
    Phoenix.PubSub.broadcast(MainApp.PubSub, topic, msg)
    byte_size_of(msg)
  end

  defp byte_size_of(msg) do
    :erlang.term_to_binary(msg) |> byte_size()
  end
end
