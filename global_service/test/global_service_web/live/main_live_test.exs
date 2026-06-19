defmodule GlobalServiceWeb.MainLiveTest do
  use GlobalServiceWeb.ConnCase, async: false

  test "renders global dashboard initial state", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Global Service Dashboard"
    assert html =~ "Total clicks:"
    assert html =~ "Pub/Sub Traffic"
  end

  test "handle_info/2 click updates logs and bytes" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    socket = Phoenix.Component.assign(socket, logs: [], ui_recv_bytes: 0)

    msg = %{
      event: "click",
      session_id: "test-user-session",
      timestamp: "2026-06-19T12:00:00"
    }

    {:noreply, updated_socket} = GlobalServiceWeb.MainLive.handle_info(msg, socket)

    assert "2026-06-19T12:00:00: test-user-session clicked" in updated_socket.assigns.logs
    assert updated_socket.assigns.ui_recv_bytes > 0
  end

  test "handle_info/2 view count updates clicks count" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    socket =
      Phoenix.Component.assign(socket,
        clicks: 0,
        backend_sent: 0,
        backend_recv: 0,
        ui_recv_bytes: 0
      )

    state = GlobalService.GlobalClickAggregatorService.get_state()
    count = state.global_clicks

    msg = %{
      view: :global,
      count: count
    }

    {:noreply, updated_socket} = GlobalServiceWeb.MainLive.handle_info(msg, socket)

    assert updated_socket.assigns.clicks == count
    assert updated_socket.assigns.ui_recv_bytes > 0
  end
end
