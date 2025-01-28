import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :private_service, PrivateServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+exBycR7BvyNnEtZ1yvxEiFHi7Wg7KEdFFx1+/CkzuKFd6Lj3Ea5AX7L2nY8674U",
  server: false

# In test we don't send emails
config :private_service, PrivateService.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
