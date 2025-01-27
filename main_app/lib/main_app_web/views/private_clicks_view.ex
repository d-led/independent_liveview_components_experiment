defmodule MainAppWeb.PrivateClickViews do
  use MainAppWeb, :html

  def render(assigns) do
    ~H"""
    <div>
      <h2>Your clicks: {@count}</h2>
    </div>
    """
  end
end
