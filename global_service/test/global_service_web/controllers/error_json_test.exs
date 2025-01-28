defmodule GlobalServiceWeb.ErrorJSONTest do
  use GlobalServiceWeb.ConnCase, async: true

  test "renders 404" do
    assert GlobalServiceWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert GlobalServiceWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
