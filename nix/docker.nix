{ pkgs, greenlight }:

pkgs.dockerTools.buildLayeredImage {
  name = "ghcr.io/jordangarrison/greenlight";
  tag = "latest";

  contents = [
    greenlight
    pkgs.cacert
  ];

  config = {
    Cmd = [ "/bin/server" ];
    ExposedPorts."4000/tcp" = { };
    Env = [
      "PHX_SERVER=true"
      "GREENLIGHT_LISTEN_ADDRESS=0.0.0.0"
      "RELEASE_DISTRIBUTION=none"
      "ERL_EPMD_ADDRESS=127.0.0.1"
    ];
  };
}
