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
    hash = "sha256-Wbv2hJLD1Wwcp+CmMuNuT5GB0BVKccHCjzDhBZpysso=";
  };

  npmDeps = fetchNpmDeps {
    name = "${pname}-npm-deps";
    src = src + "/assets";
    hash = "sha256-BLuc+yYQ0rQpAWnLa1nDk7Q8mhvcgWGVT5Ywlth8opo=";
  };
in
mixRelease {
  inherit pname version src mixFodDeps;

  nativeBuildInputs = [ nodejs ];

  # Tailwind is configured via MIX_TAILWIND_PATH in config.exs
  MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";

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
