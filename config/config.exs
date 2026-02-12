# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :greenlight,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :greenlight, GreenlightWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GreenlightWeb.ErrorHTML, json: GreenlightWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Greenlight.PubSub,
  live_view: [signing_salt: "sursZSB/"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :greenlight, Greenlight.Mailer, adapter: Swoosh.Adapters.Local

# Configure tailwind (the version is required)
config :tailwind,
  path: System.get_env("MIX_TAILWIND_PATH"),
  version: "4.1.18",
  greenlight: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :greenlight,
  github_token: System.get_env("GITHUB_TOKEN"),
  bookmarked_repos: [],
  followed_orgs: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
