defmodule GlobalServiceWeb.GlobalClicksViewTest do
  use GlobalServiceWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias GlobalServiceWeb.GlobalClicksView

  test "renders global clicks with given count" do
    html = render_component(&GlobalClicksView.render/1, count: 42)
    assert html =~ "Total clicks: 42"
  end

  test "renders node name in output" do
    html = render_component(&GlobalClicksView.render/1, count: 1)
    assert html =~ "Node name:"
  end
end
