{
  description = "Greenlight - Elixir Phoenix application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        erlang = pkgs.beam.packages.erlang_28;
        elixir = erlang.elixir;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            elixir
            erlang.erlang

            # Database
            pkgs.postgresql

            # Asset pipeline - provide system binaries so Phoenix
            # doesn't download its own (which won't work on NixOS)
            pkgs.esbuild
            pkgs.tailwindcss_4

            # File watching for live reload
            pkgs.inotify-tools
          ];

          env = {
            # Tell Phoenix to use system esbuild/tailwind instead of downloading
            MIX_ESBUILD_PATH = "${pkgs.esbuild}/bin/esbuild";
            MIX_TAILWIND_PATH = "${pkgs.tailwindcss_4}/bin/tailwindcss";

            # Locale settings for Elixir
            LANG = "en_US.UTF-8";
            ERL_AFLAGS = "-kernel shell_history enabled";
          };

          shellHook = ''
            mix local.hex --if-missing --force
            mix local.rebar --if-missing --force
          '';
        };
      });
}
