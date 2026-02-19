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
        packages = {
          default = pkgs.callPackage ./nix/package.nix {
            beamPackages = erlang;
          };
        } // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          dockerImage = import ./nix/docker.nix {
            inherit pkgs;
            greenlight = self.packages.${system}.default;
          };
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
