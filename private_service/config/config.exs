# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :private_service,
  generators: [timestamp_type: :utc_datetime]

config :private_service, MainApp.PubSub,
  adapter: Phoenix.PubSub.PG2

# Configures the endpoint
config :private_service, PrivateServiceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrivateServiceWeb.ErrorHTML, json: PrivateServiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MainApp.PubSub,
  live_view: [signing_salt: "cuyK6RSm"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :private_service, PrivateService.Mailer, adapter: Swoosh.Adapters.Local

config :private_service, PrivateService.Presence,
  pubsub_server: MainApp.PubSub

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  private_service: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  private_service: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
