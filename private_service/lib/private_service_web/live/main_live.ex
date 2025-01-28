defmodule PrivateServiceWeb.MainLive do
  use PrivateServiceWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-4 w-full h-full">
      <div class="col-span-1 w-full border border-light-gray-300 p-4 relative">
        <div class="absolute -top-3 left-4 bg-white px-1">Operations</div>
        test
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
