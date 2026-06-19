defmodule MainAppWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :global_service,
    pubsub_server: MainApp.PubSub
end
