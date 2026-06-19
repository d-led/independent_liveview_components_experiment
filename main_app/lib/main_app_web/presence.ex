defmodule MainAppWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :main_app,
    pubsub_server: MainApp.PubSub
end
