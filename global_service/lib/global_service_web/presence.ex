defmodule GlobalServiceWeb.Presence do
  use Phoenix.Presence,
    otp_app: :global_service,
    pubsub_server: MainApp.PubSub
end
