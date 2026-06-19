defmodule PrivateServiceWeb.PrivateClickViewsTest do
  use PrivateServiceWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PrivateServiceWeb.PrivateClickViews

  test "renders private clicks with count and session_id" do
    html = render_component(&PrivateClickViews.render/1, count: 5, session_id: "test-session-xyz")
    assert html =~ "Your clicks: 5"
    assert html =~ "Session: test-session-xyz"
  end

  test "renders node name in output" do
    html = render_component(&PrivateClickViews.render/1, count: 0, session_id: "test-session")
    assert html =~ "Node name:"
  end
end
