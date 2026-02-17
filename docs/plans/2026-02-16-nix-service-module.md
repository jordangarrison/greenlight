# Nix Flake Package & NixOS Service Module

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Package greenlight as a Nix derivation and provide a NixOS service module so it can be deployed declaratively with secrets, list configs, and optional nginx reverse proxy.

**Architecture:** The flake exports a `mixRelease` package (built with Nix-provided tailwind/esbuild/node), a NixOS module at `nixosModules.default` that creates a systemd service with `LoadCredential` for secrets and `environmentFile` as a catch-all, and optional nginx virtualhost configuration. The NodeJS SSR supervisor in `application.ex` becomes conditional so the release runs without Node.js at runtime.

**Tech Stack:** Nix flakes, `beamPackages.mixRelease`, `fetchMixDeps`, `fetchNpmDeps`, NixOS module system, systemd

---

### Task 1: Generate Phoenix Release Overlay

**Files:**
- Create: `rel/overlays/bin/server` (generated)
- Create: `rel/overlays/bin/server.bat` (generated)

**Step 1: Generate release files**

Run: `mix phx.gen.release --no-ecto`

This creates `rel/overlays/bin/server` which sets `PHX_SERVER=true` and starts the release.

**Step 2: Verify generated files exist**

Run: `ls -la rel/overlays/bin/`
Expected: `server` and `server.bat` files

**Step 3: Commit**

```bash
git add rel/
git commit -m "feat: generate phoenix release overlay (no ecto)"
```

---

### Task 2: Make NodeJS SSR Supervisor Conditional

The application currently unconditionally starts `NodeJS.Supervisor` for LiveSvelte SSR. In a release without Node.js, this will crash. Make it conditional based on config.

**Files:**
- Modify: `lib/greenlight/application.ex`
- Modify: `config/config.exs` (add default `ssr_enabled: true`)
- Modify: `config/prod.exs` (or `runtime.exs` — set `ssr_enabled` from env)

**Step 1: Add SSR config flag**

In `config/config.exs`, add to the existing greenlight config block:

```elixir
config :greenlight,
  generators: [timestamp_type: :utc_datetime],
  ssr_enabled: true
```

In `config/runtime.exs`, after the existing greenlight_config block, add:

```elixir
greenlight_config =
  case System.get_env("GREENLIGHT_SSR_ENABLED") do
    "false" -> Keyword.put(greenlight_config, :ssr_enabled, false)
    _ -> greenlight_config
  end
```

**Step 2: Make NodeJS.Supervisor conditional in application.ex**

Replace the static children list with conditional SSR:

```elixir
def start(_type, _args) do
  ssr_children =
    if Application.get_env(:greenlight, :ssr_enabled, true) do
      [{NodeJS.Supervisor, [path: LiveSvelte.SSR.NodeJS.server_path(), pool_size: 4]}]
    else
      []
    end

  children =
    ssr_children ++
      [
        GreenlightWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:greenlight, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Greenlight.PubSub},
        {Registry, keys: :unique, name: Greenlight.PollerRegistry},
        {DynamicSupervisor, name: Greenlight.PollerSupervisor, strategy: :one_for_one},
        GreenlightWeb.Endpoint
      ]

  opts = [strategy: :one_for_one, name: Greenlight.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Step 3: Run tests to verify nothing breaks**

Run: `mix test`
Expected: All tests pass (SSR is still enabled by default)

**Step 4: Commit**

```bash
git add lib/greenlight/application.ex config/config.exs config/runtime.exs
git commit -m "feat: make LiveSvelte SSR supervisor conditional via config"
```

---

### Task 3: Add Listen Address Config to runtime.exs

Currently prod binds to `{0, 0, 0, 0, 0, 0, 0, 0}` (all interfaces). Add env var support so the NixOS module can control the bind address.

**Files:**
- Modify: `config/runtime.exs`

**Step 1: Add GREENLIGHT_LISTEN_ADDRESS parsing**

In the `if config_env() == :prod do` block of `config/runtime.exs`, replace the static `ip` tuple:

```elixir
listen_ip =
  case System.get_env("GREENLIGHT_LISTEN_ADDRESS", "::") do
    "::" -> {0, 0, 0, 0, 0, 0, 0, 0}
    addr ->
      addr
      |> String.to_charlist()
      |> :inet.parse_address()
      |> case do
        {:ok, ip} -> ip
        {:error, _} -> {0, 0, 0, 0, 0, 0, 0, 0}
      end
  end

config :greenlight, GreenlightWeb.Endpoint,
  url: [host: host, port: 443, scheme: "https"],
  http: [ip: listen_ip],
  secret_key_base: secret_key_base
```

**Step 2: Run tests**

Run: `mix test`
Expected: All pass (this only affects prod config)

**Step 3: Commit**

```bash
git add config/runtime.exs
git commit -m "feat: add configurable listen address via GREENLIGHT_LISTEN_ADDRESS"
```

---

### Task 4: Create the Nix Package Derivation

**Files:**
- Create: `nix/package.nix`

**Step 1: Write the package derivation**

Create `nix/package.nix`:

```nix
{
  lib,
  beamPackages,
  nodejs,
  tailwindcss_4,
  fetchNpmDeps,
  mixRelease ? beamPackages.mixRelease,
  fetchMixDeps ? beamPackages.fetchMixDeps,
}:

let
  pname = "greenlight";
  version = "0.1.0";
  src = ./..;

  mixFodDeps = fetchMixDeps {
    pname = "${pname}-mix-deps";
    inherit version src;
    hash = lib.fakeHash;
  };

  npmDeps = fetchNpmDeps {
    name = "${pname}-npm-deps";
    inherit src;
    sourceRoot = "${src.name}/assets";
    hash = lib.fakeHash;
  };
in
mixRelease {
  inherit pname version src mixFodDeps;

  nativeBuildInputs = [ nodejs ];

  # Tailwind is configured via MIX_TAILWIND_PATH in config.exs,
  # which reads from env. Inject it here for the build.
  MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";

  # SSR is disabled in the release — no Node.js at runtime
  GREENLIGHT_SSR_ENABLED = "false";

  preBuild = ''
    # Install npm dependencies for the asset pipeline
    cd assets
    export npm_config_cache=${npmDeps}
    npm ci --ignore-scripts
    cd ..
  '';

  postBuild = ''
    mix do deps.loadpaths --no-deps-check, assets.deploy
  '';
}
```

**Note:** The `lib.fakeHash` values will cause the first build to fail with the correct hash. This is expected — update the hashes after the first `nix build` attempt.

**Step 2: Attempt a build to get correct hashes**

Run: `nix build .#default`
Expected: Fails with hash mismatch. Copy the "got:" hash for `mixFodDeps`, update `nix/package.nix`, repeat for `npmDeps`.

This is iterative — may take 2-3 rounds. The `file:../deps/...` references in `package.json` are resolved because `mixRelease` makes mix deps available before `preBuild` runs.

**Step 3: Verify the build succeeds**

Run: `nix build .#default`
Expected: Build completes, `result/bin/greenlight` and `result/bin/server` exist.

Run: `ls result/bin/`
Expected: `greenlight`, `server` (and possibly `greenlight_rc.sh`)

**Step 4: Commit**

```bash
git add nix/package.nix
git commit -m "feat: add nix package derivation for mixRelease build"
```

---

### Task 5: Create the NixOS Service Module

**Files:**
- Create: `nix/module.nix`

**Step 1: Write the NixOS module**

Create `nix/module.nix`:

```nix
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
        GREENLIGHT_SSR_ENABLED = "false";
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
```

**Step 2: Commit**

```bash
git add nix/module.nix
git commit -m "feat: add NixOS service module with secrets, nginx, and list config"
```

---

### Task 6: Update flake.nix to Export Package and Module

**Files:**
- Modify: `flake.nix`

**Step 1: Rewrite flake.nix**

The flake needs to export `packages`, `devShells` (per-system), and `nixosModules` (system-agnostic). Replace the current `flake.nix`:

```nix
{
  description = "Greenlight - GitHub Actions workflow visualizer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    # Per-system outputs: packages + devShells
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        erlang = pkgs.beam.packages.erlang_28;
        elixir = erlang.elixir;
      in
      {
        packages.default = pkgs.callPackage ./nix/package.nix {
          beamPackages = erlang;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            elixir
            erlang.erlang
            pkgs.postgresql
            pkgs.tailwindcss_4
            pkgs.nodejs
            pkgs.inotify-tools
            pkgs.watchman
          ];

          env = {
            MIX_TAILWIND_PATH = "${pkgs.tailwindcss_4}/bin/tailwindcss";
            LANG = "en_US.UTF-8";
            ERL_AFLAGS = "-kernel shell_history enabled";
          };

          shellHook = ''
            mix local.hex --if-missing --force
            mix local.rebar --if-missing --force
          '';
        };
      }
    ))
    //
    # System-agnostic outputs: NixOS module
    {
      nixosModules.default = import ./nix/module.nix self;
    };
}
```

**Step 2: Verify flake evaluates**

Run: `nix flake check`
Expected: No evaluation errors (build may still fail until hashes are fixed in Task 4)

**Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat: expand flake with package output and NixOS module"
```

---

### Task 7: Iterate on Build Hashes

This task is iterative — run `nix build`, capture hash mismatches, update `nix/package.nix`.

**Files:**
- Modify: `nix/package.nix`

**Step 1: Get mixFodDeps hash**

Run: `nix build .#default 2>&1 | grep "got:"`
Copy the hash and replace `lib.fakeHash` for `mixFodDeps` in `nix/package.nix`.

**Step 2: Get npmDeps hash**

Run: `nix build .#default 2>&1 | grep "got:"`
Copy the hash and replace `lib.fakeHash` for `npmDeps` in `nix/package.nix`.

**Step 3: Repeat until build succeeds**

Run: `nix build .#default`
Expected: `./result/bin/greenlight` and `./result/bin/server` exist

**Step 4: Verify the release starts (smoke test)**

Run: `SECRET_KEY_BASE=$(mix phx.gen.secret) GITHUB_TOKEN=test PHX_SERVER=true ./result/bin/greenlight start`
Expected: Server starts (may fail on GitHub API, but the BEAM boots)
Kill with Ctrl+C.

**Step 5: Commit**

```bash
git add nix/package.nix
git commit -m "fix: set correct dependency hashes for nix build"
```

---

### Task 8: Verify and Final Commit

**Step 1: Run mix precommit**

Run: `mix precommit`
Expected: Compiles cleanly, formatter happy, tests pass

**Step 2: Run nix flake check**

Run: `nix flake check`
Expected: No errors

**Step 3: Final commit if any fixups needed**

```bash
git add -A
git commit -m "chore: fixups from precommit and flake check"
```
