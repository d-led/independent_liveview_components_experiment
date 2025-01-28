defmodule PrivateServiceWeb.PrivateClickViews do
  use PrivateServiceWeb, :html

  def render(assigns) do
    ~H"""
    <div>
      <h2>Session: {@session_id}</h2>
      <p>Node name: <%= Node.self() %></p>
      <h2>Your clicks: {@count}</h2>
    </div>
    """
  end
end
