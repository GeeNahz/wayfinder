import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :wayfinder, Wayfinder.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "wayfinder_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wayfinder, WayfinderWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "y3aVKupVaoMFFrvQQxcMV0ob+pBnxtkSJxCq30kQrInUhN5ozjPzQmzfvNw/+Ixx",
  server: false

# In test we don't send emails
config :wayfinder, Wayfinder.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Don't run the hourly clean-up process in tests
config :wayfinder, :start_janitor, false

# Never call real external services from tests
config :wayfinder, :geocoder, Wayfinder.Geocoding.Stub
config :wayfinder, Wayfinder.Turnstile, req_options: [plug: {Req.Test, Wayfinder.Turnstile}]

config :wayfinder, Wayfinder.Geocoding.Nominatim,
  req_options: [plug: {Req.Test, Wayfinder.Geocoding.Nominatim}]
