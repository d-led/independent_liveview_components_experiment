defmodule MainAppWeb.GlobalClicksView do
  use MainAppWeb, :html

  def render(assigns) do
    ~H"""
    <div>
      <h2>Total clicks: {@count}</h2>
    </div>
    """
  end
end
