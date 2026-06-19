defmodule GlobalServiceWeb.GlobalClicksView do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>
      <p>Node name: {Node.self()}</p>
      <h2>Total clicks: {@count}</h2>
    </div>
    """
  end
end
