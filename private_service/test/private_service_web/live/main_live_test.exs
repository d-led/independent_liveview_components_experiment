defmodule PrivateServiceWeb.MainLiveTest do
  use PrivateServiceWeb.ConnCase, async: false

  test "renders private service dashboard initial state", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Sessions Service Dashboard"
    assert html =~ "Sessions"
    assert html =~ "Pub/Sub Traffic"
  end

  test "handle_info/2 click event updates session clicks and bytes" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    socket = Phoenix.Component.assign(socket, sessions: %{}, ui_recv_bytes: 0)

    msg = %{
      event: "click",
      session_id: "test-user-session",
      timestamp: "2026-06-19T12:00:00"
    }

    {:noreply, updated_socket} = PrivateServiceWeb.MainLive.handle_info(msg, socket)

    assert Map.get(updated_socket.assigns.sessions, "test-user-session") == 1
    assert updated_socket.assigns.ui_recv_bytes > 0
  end

  test "handle_info/2 presence:lobby broadcast updates sessions and presence" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    socket = Phoenix.Component.assign(socket,
      sessions: %{},
      online_sessions: [],
      backend_sent: 0,
      backend_recv: 0,
      ui_recv_bytes: 0
    )

    msg = %Phoenix.Socket.Broadcast{
      topic: "presence:lobby",
      event: "presence_diff",
      payload: %{joins: %{}, leaves: %{}}
    }

    {:noreply, updated_socket} = PrivateServiceWeb.MainLive.handle_info(msg, socket)

    # Verifies presence mapping and aggregator query doesn't crash
    assert is_map(updated_socket.assigns.sessions)
    assert is_list(updated_socket.assigns.online_sessions)
    assert updated_socket.assigns.ui_recv_bytes > 0
  end
end
