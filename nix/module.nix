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
      type = lib.types.str;
      description = ''
        Absolute path to a file containing the GitHub API token.
        Must NOT be a Nix store path.
        File must contain the bare token value only — no KEY=VALUE format, no trailing newline.
        Consider using sops-nix or agenix for secret management.
      '';
    };

    secretKeyBaseFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Absolute path to a file containing the Phoenix SECRET_KEY_BASE.
        Must NOT be a Nix store path.
        File must contain the bare value only — no KEY=VALUE format, no trailing newline.
        Generate with: mix phx.gen.secret or openssl rand -base64 64
        Consider using sops-nix or agenix for secret management.
      '';
    };

    # Catch-all environment file for additional secrets/overrides
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path to an environment file as defined in {manpage}`systemd.exec(5)`.
        Must NOT be a Nix store path.
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
    assertions = [
      {
        assertion = !(cfg.nginx.enable && cfg.host == "localhost");
        message = "services.greenlight: nginx is enabled but host is 'localhost'. ACME certificate provisioning will fail. Set a real public hostname.";
      }
      {
        assertion = !(cfg.nginx.enableACME && (builtins.match "^[0-9.:]+$" cfg.host != null || lib.hasSuffix ".local" cfg.host));
        message = "services.greenlight: ACME is enabled but host appears to be an IP address or .local domain. ACME requires a public DNS name.";
      }
      {
        assertion = !(cfg.openFirewall && cfg.nginx.enable);
        message = "services.greenlight: openFirewall and nginx are both enabled. openFirewall exposes port ${toString cfg.port} directly. You probably want to open ports 80/443 via nginx instead.";
      }
    ];

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
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = [ pkgs.nodejs ];

      environment = {
        PORT = toString cfg.port;
        PHX_HOST = cfg.host;
        PHX_SERVER = "true";
        PHX_SCHEME = if cfg.nginx.enable then "https" else "http";
        PHX_URL_PORT = toString (if cfg.nginx.enable then 443 else cfg.port);
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
        # Persist release cookie so `bin/greenlight remote` works across restarts
        COOKIE_FILE="/var/lib/greenlight/.erlang.cookie"
        if [ ! -f "$COOKIE_FILE" ]; then
          tr -dc A-Za-z0-9 < /dev/urandom | head -c 20 > "$COOKIE_FILE"
          chmod 400 "$COOKIE_FILE"
        fi
        export RELEASE_COOKIE="$(< "$COOKIE_FILE")"

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
        CapabilityBoundingSet = "";
        ProtectKernelLogs = true;
        UMask = "0077";
      };
    };

    # Optional nginx reverse proxy
    services.nginx = lib.mkIf cfg.nginx.enable (let
      urlAddr = if lib.hasInfix ":" cfg.listenAddress
        then "[${cfg.listenAddress}]"
        else cfg.listenAddress;
    in {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts.${cfg.host} = {
        forceSSL = true;
        enableACME = cfg.nginx.enableACME;

        locations."/" = {
          proxyPass = "http://${urlAddr}:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    });
  };
}
