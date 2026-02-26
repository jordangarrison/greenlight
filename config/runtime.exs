import Config

# Allow runtime log level override (e.g., LOG_LEVEL=debug in prod)
if log_level = System.get_env("LOG_LEVEL") do
  config :logger, level: String.to_existing_atom(log_level)
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/greenlight start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :greenlight, GreenlightWeb.Endpoint, server: true
end

config :greenlight, GreenlightWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

greenlight_config =
  [
    bookmarked_repos:
      System.get_env("GREENLIGHT_BOOKMARKED_REPOS", "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1),
    followed_orgs:
      System.get_env("GREENLIGHT_FOLLOWED_ORGS", "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
  ]

greenlight_config =
  case System.get_env("GITHUB_TOKEN") do
    nil -> greenlight_config
    token -> Keyword.put(greenlight_config, :github_token, token)
  end

greenlight_config =
  case System.get_env("GREENLIGHT_SSR_POOL_SIZE") do
    nil -> greenlight_config
    size -> Keyword.put(greenlight_config, :ssr_pool_size, String.to_integer(size))
  end

config :greenlight, greenlight_config

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :greenlight, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  listen_ip =
    case System.get_env("GREENLIGHT_LISTEN_ADDRESS", "127.0.0.1") do
      "::" ->
        {0, 0, 0, 0, 0, 0, 0, 0}

      addr ->
        addr
        |> String.to_charlist()
        |> :inet.parse_address()
        |> case do
          {:ok, ip} ->
            ip

          {:error, _} ->
            raise "invalid GREENLIGHT_LISTEN_ADDRESS: #{inspect(addr)}"
        end
    end

  port = String.to_integer(System.get_env("PORT", "4000"))

  scheme = System.get_env("PHX_SCHEME", "https")
  url_port = String.to_integer(System.get_env("PHX_URL_PORT", "443"))

  check_origin =
    case System.get_env("PHX_CHECK_ORIGIN") do
      nil -> true
      "false" -> false
      origins -> String.split(origins, ",", trim: true) |> Enum.map(&String.trim/1)
    end

  config :greenlight, GreenlightWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    http: [ip: listen_ip, port: port],
    secret_key_base: secret_key_base,
    check_origin: check_origin

  if scheme == "https" do
    config :greenlight, GreenlightWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto]]
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :greenlight, GreenlightWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :greenlight, GreenlightWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :greenlight, Greenlight.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
