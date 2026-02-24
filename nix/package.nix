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
    hash = "sha256-ekvwtyOduUlUdoIO8s359yDLGGq2VDRzMVvYG8AJVz0=";
  };

  npmDeps = fetchNpmDeps {
    name = "${pname}-npm-deps";
    src = src + "/assets";
    hash = "sha256-4nVNhge0L/dATqmzzlInLp2nrWc5e2B5S8JBQHtmT3I=";
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
