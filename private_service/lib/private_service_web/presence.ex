defmodule MainAppWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :private_service,
    pubsub_server: MainApp.PubSub
end
