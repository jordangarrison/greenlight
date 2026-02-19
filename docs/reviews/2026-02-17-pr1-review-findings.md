# PR #1 Review Findings: Nix Package and NixOS Service Module

Consolidated findings from four parallel reviews: security, Nix expert, self-hosting, and Phoenix/Elixir expert.

Branch: `feat/nix-service-module`
PR: https://github.com/jordangarrison/greenlight/pull/1

## Should Fix

### 1. Default listen address in runtime.exs is `::` (all interfaces)

**File:** `config/runtime.exs:70`
**Source:** Security, Self-hosting

Outside the NixOS module (e.g., Docker, manual deploy, testing in prod mode), the app binds to all interfaces by default with no warning. The NixOS module defaults to `127.0.0.1`, but `runtime.exs` defaults to `::`.

**Fix:** Change the default from `"::"` to `"127.0.0.1"`:

```elixir
case System.get_env("GREENLIGHT_LISTEN_ADDRESS", "127.0.0.1") do
```

If someone wants all-interface binding, they can explicitly set `GREENLIGHT_LISTEN_ADDRESS=::`.

### 2. `propagatedBuildInputs = [ nodejs ]` is wrong

**File:** `nix/package.nix:37`
**Source:** Nix

`propagatedBuildInputs` in this context pulls in the `-dev` output of nodejs (V8 build tools like `mksnapshot`, `torque` — ~65MB) and does NOT put the `node` binary on the runtime PATH. The module's `path = lib.mkIf cfg.ssrEnabled [ pkgs.nodejs ]` already handles making Node.js available at runtime correctly.

**Fix:** Remove `propagatedBuildInputs` entirely:

```nix
# Remove this line:
propagatedBuildInputs = [ nodejs ];
```

`nativeBuildInputs = [ nodejs ]` remains for build-time asset compilation.

### 3. IPv6 in nginx proxyPass breaks

**File:** `nix/module.nix:215`
**Source:** Security, Phoenix

If `listenAddress` is an IPv6 address like `::1`, the generated `proxyPass` would be `http://::1:4000` which is an invalid URL. IPv6 addresses in URLs must be bracketed: `http://[::1]:4000`.

**Fix:** Add bracket wrapping for IPv6:

```nix
let
  urlAddr = if lib.hasInfix ":" cfg.listenAddress
    then "[${cfg.listenAddress}]"
    else cfg.listenAddress;
in
# ...
proxyPass = "http://${urlAddr}:${toString cfg.port}";
```

### 4. SSR disable path is noisy — also set `config :live_svelte, ssr: false`

**File:** `config/runtime.exs:44-48`
**Source:** Phoenix

When `GREENLIGHT_SSR_ENABLED=false`, `NodeJS.Supervisor` is not started. However, LiveSvelte still checks its own config (`Application.get_env(:live_svelte, :ssr, true)`) and defaults to `true`. This means every component's initial dead render attempts to call NodeJS, hits `:noproc`, raises `SSR.NotConfigured`, and rescues it. It works but is unnecessarily noisy and slower.

**Fix:** Also set the LiveSvelte config when disabling SSR:

```elixir
greenlight_config =
  case System.get_env("GREENLIGHT_SSR_ENABLED") do
    "false" ->
      config :live_svelte, ssr: false
      Keyword.put(greenlight_config, :ssr_enabled, false)
    _ -> greenlight_config
  end
```

### 5. Secret file option types allow Nix store paths

**File:** `nix/module.nix:65,70`
**Source:** Security

The type `lib.types.either lib.types.path lib.types.str` allows a bare Nix path literal (e.g., `githubTokenFile = ./my-secret;`). When a Nix `path` value is used, the file is copied into the Nix store (`/nix/store/...`), which is world-readable. This defeats the purpose of `LoadCredential`.

**Fix:** Change the type to `lib.types.str` only:

```nix
githubTokenFile = lib.mkOption {
  type = lib.types.str;
  description = "Absolute path to a file containing the GitHub API token. Must NOT be a Nix store path.";
};

secretKeyBaseFile = lib.mkOption {
  type = lib.types.str;
  description = ''
    Absolute path to a file containing the Phoenix SECRET_KEY_BASE.
    Must NOT be a Nix store path.
    Generate with: openssl rand -base64 64
  '';
};
```

### 6. nginx.enableACME = false with nginx.enable = true creates a mismatch

**File:** `nix/module.nix:109-111,138`
**Source:** Security, Self-hosting

`forceSSL` is tied to `enableACME`. If someone sets `nginx.enable = true; nginx.enableACME = false` (intending to use their own cert), both `forceSSL` and `enableACME` become `false`, resulting in an HTTP-only nginx vhost. Meanwhile `PHX_SCHEME` is still `"https"`, causing `force_ssl` to be active inside Phoenix but nginx serves HTTP only — creating a redirect mismatch.

**Fix:** Decouple `forceSSL` from `enableACME`. Always force SSL when nginx is enabled, and let ACME be independent:

```nix
virtualHosts.${cfg.host} = {
  forceSSL = true;
  enableACME = cfg.nginx.enableACME;
  # ...
};
```

Or add a separate `nginx.forceSSL` option.

### 7. Use `network-online.target` instead of `network.target`

**File:** `nix/module.nix:130`
**Source:** Self-hosting

The app makes outbound HTTPS requests to the GitHub API. `network.target` only means network interfaces are configured, not that there is actual connectivity. On a NixOS box using DHCP or Wi-Fi, the service can start before the network is actually up.

**Fix:**

```nix
wantedBy = [ "multi-user.target" ];
wants = [ "network-online.target" ];
after = [ "network-online.target" ];
```

### 8. Missing systemd hardening directives

**File:** `nix/module.nix:184-200`
**Source:** Security

The current hardening is solid but missing several directives. The service binds to port 4000 (unprivileged) and needs no capabilities.

**Fix:** Add to `serviceConfig`:

```nix
CapabilityBoundingSet = "";
ProtectKernelLogs = true;
UMask = "0077";
```

Do NOT add `MemoryDenyWriteExecute = true` — the BEAM VM uses mmap with execute permission for JIT.

## Nice-to-Have (not blocking)

### 9. Add NixOS assertions for common misconfigurations

- `nginx.enable = true` + `host = "localhost"` (ACME will fail)
- `nginx.enableACME = true` + host is IP address or `.local` domain
- `openFirewall = true` + `nginx.enable = true` (probably want 80/443, not 4000)

### 10. Improve secret file option descriptions

- Mention `openssl rand -base64 64` as alternative to `mix phx.gen.secret` (deployer may not have mix)
- Warn that file must contain bare value, no trailing newline, no `KEY=VALUE` format
- Mention sops-nix / agenix as recommended secret management

### 11. SSR pool_size (4) is hardcoded

`pool_size: 4` in `application.ex:12` means 4 Node.js worker processes. For a Raspberry Pi or low-end homelab, this is heavy. Consider making it configurable via env var.

### 12. RELEASE_COOKIE regenerated every restart

The script generates a random `RELEASE_COOKIE` each start. Since `RELEASE_DISTRIBUTION = "none"`, this is harmless, but remote IEx shell (`bin/greenlight remote`) will never work. Consider persisting the cookie to `StateDirectory` on first boot.

### 13. Use `lib.fileset` for tighter source filtering

`src = ./..` includes the entire repo. Using `lib.fileset` would give better hash stability and build cache hits.

### 14. Quote `$CREDENTIALS_DIRECTORY` in the bash script

Defensive quoting: `"$CREDENTIALS_DIRECTORY"` instead of `$CREDENTIALS_DIRECTORY`. Systemd won't put spaces in it, but it's good practice.
