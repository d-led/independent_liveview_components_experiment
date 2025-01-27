defmodule MainAppWeb.ErrorJSONTest do
  use MainAppWeb.ConnCase, async: true

  test "renders 404" do
    assert MainAppWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert MainAppWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
