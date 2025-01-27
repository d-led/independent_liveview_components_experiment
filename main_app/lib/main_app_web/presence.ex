defmodule MainAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :main_app,
    pubsub_server: MainApp.PubSub
end
