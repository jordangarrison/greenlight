{ pkgs, greenlight }:

pkgs.dockerTools.buildLayeredImage {
  name = "ghcr.io/jordangarrison/greenlight";
  tag = "latest";

  contents = [
    greenlight
    pkgs.cacert
    pkgs.nodejs-slim  # Required at runtime for live_svelte SSR (slim: no npm/docs)
  ];

  config = {
    Cmd = [ "/bin/server" ];
    ExposedPorts."4000/tcp" = { };
    Env = [
      "PHX_SERVER=true"
      "GREENLIGHT_LISTEN_ADDRESS=0.0.0.0"
      "RELEASE_DISTRIBUTION=none"
      "ERL_EPMD_ADDRESS=127.0.0.1"
      "RELEASE_COOKIE=greenlight-container"
      "ELIXIR_ERL_OPTIONS=+fnu"
      "PHX_SCHEME=http"
      "PHX_URL_PORT=4000"
    ];
  };
}
