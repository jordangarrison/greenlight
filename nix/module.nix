self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.greenlight;
in
{
  options.services.greenlight = {
    enable = lib.mkEnableOption "Greenlight GitHub Actions visualizer";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.default;
      defaultText = lib.literalExpression "self.packages.\${pkgs.system}.default";
      description = "The Greenlight package to use.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      example = "greenlight.example.com";
      description = "Public hostname for the application (PHX_HOST).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "Port the application listens on.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address to bind the HTTP server to.";
    };

    bookmarkedRepos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "owner/repo1" "owner/repo2" ];
      description = "Repositories to pin on the dashboard.";
    };

    followedOrgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nixos" "anthropics" ];
      description = "GitHub organizations to follow.";
    };

    dnsClusterQuery = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional DNS cluster discovery query for distributed deployments.";
    };

    # Secrets — per-file via LoadCredential
    githubTokenFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      description = "Path to a file containing the GitHub API token.";
    };

    secretKeyBaseFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      description = ''
        Path to a file containing the Phoenix SECRET_KEY_BASE.
        Generate one with: mix phx.gen.secret
      '';
    };

    # Catch-all environment file for additional secrets/overrides
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`.
        Secrets may be passed to the service without adding them to the
        world-readable Nix store. Format: KEY=VALUE, one per line.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the service port.";
    };

    nginx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to configure an nginx virtualhost for Greenlight.";
      };

      enableACME = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable ACME (Let's Encrypt) for the nginx virtualhost.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System user
    users.users.greenlight = {
      isSystemUser = true;
      group = "greenlight";
    };
    users.groups.greenlight = { };

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Systemd service
    systemd.services.greenlight = {
      description = "Greenlight - GitHub Actions Workflow Visualizer";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        PORT = toString cfg.port;
        PHX_HOST = cfg.host;
        PHX_SERVER = "true";
        GREENLIGHT_LISTEN_ADDRESS = cfg.listenAddress;
        RELEASE_DISTRIBUTION = "none";
        ERL_EPMD_ADDRESS = "127.0.0.1";
        HOME = "/var/lib/greenlight";
        RELEASE_TMP = "/var/lib/greenlight/tmp";
      } // lib.optionalAttrs (cfg.bookmarkedRepos != [ ]) {
        GREENLIGHT_BOOKMARKED_REPOS = lib.concatStringsSep "," cfg.bookmarkedRepos;
      } // lib.optionalAttrs (cfg.followedOrgs != [ ]) {
        GREENLIGHT_FOLLOWED_ORGS = lib.concatStringsSep "," cfg.followedOrgs;
      } // lib.optionalAttrs (cfg.dnsClusterQuery != null) {
        DNS_CLUSTER_QUERY = cfg.dnsClusterQuery;
      };

      script = ''
        # Generate a random release cookie (not using distributed Erlang, but required)
        export RELEASE_COOKIE="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 20)"

        # Load secrets from systemd credentials
        export SECRET_KEY_BASE="$(< $CREDENTIALS_DIRECTORY/SECRET_KEY_BASE)"
        export GITHUB_TOKEN="$(< $CREDENTIALS_DIRECTORY/GITHUB_TOKEN)"

        exec ${cfg.package}/bin/server
      '';

      serviceConfig = {
        Type = "exec";
        User = "greenlight";
        Group = "greenlight";
        StateDirectory = "greenlight";
        RuntimeDirectory = "greenlight";
        Restart = "on-failure";
        RestartSec = 5;

        # Load secrets via systemd credentials
        LoadCredential = [
          "SECRET_KEY_BASE:${cfg.secretKeyBaseFile}"
          "GITHUB_TOKEN:${cfg.githubTokenFile}"
        ];

        # Optional catch-all environment file
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        LockPersonality = true;
      };
    };

    # Optional nginx reverse proxy
    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${cfg.host} = {
        forceSSL = cfg.nginx.enableACME;
        enableACME = cfg.nginx.enableACME;

        locations."/" = {
          proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
