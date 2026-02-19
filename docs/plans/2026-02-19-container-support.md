# Container Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Nix-built OCI container image for distributing Greenlight via Docker/GHCR.

**Architecture:** Use `pkgs.dockerTools.buildLayeredImage` in a new `nix/docker.nix` module to produce a minimal (scratch-like) OCI image containing only the Erlang release, CA certificates, and required runtime config. The image is built via `nix build .#dockerImage` and loaded with `docker load`.

**Tech Stack:** Nix (dockerTools), existing mixRelease package from `nix/package.nix`

---

### Task 1: Create `nix/docker.nix`

**Files:**
- Create: `nix/docker.nix`

**Step 1: Create the docker image module**

Create `nix/docker.nix` with the following content:

```nix
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
    ];
  };
}
```

**Step 2: Commit**

```bash
git add nix/docker.nix
git commit -m "feat: add nix/docker.nix for OCI image build"
```

---

### Task 2: Wire `dockerImage` into `flake.nix`

**Files:**
- Modify: `flake.nix:23-26` (inside the `eachDefaultSystem` block, after `packages.default`)

**Step 1: Add the dockerImage package output**

In `flake.nix`, add `packages.dockerImage` right after `packages.default` (after line 26, before `devShells.default`):

```nix
        packages.dockerImage = import ./nix/docker.nix {
          inherit pkgs;
          greenlight = self.packages.${system}.default;
        };
```

The result in `flake.nix` should look like:

```nix
      {
        packages.default = pkgs.callPackage ./nix/package.nix {
          beamPackages = erlang;
        };

        packages.dockerImage = import ./nix/docker.nix {
          inherit pkgs;
          greenlight = self.packages.${system}.default;
        };

        devShells.default = pkgs.mkShell {
```

**Step 2: Verify the flake evaluates**

Run: `nix flake check --no-build`
Expected: No evaluation errors (build is skipped, just checks the flake structure)

**Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat: wire dockerImage output into flake.nix"
```

---

### Task 3: Build and verify the image

**Step 1: Build the docker image**

Run: `nix build .#dockerImage`
Expected: A `result` symlink is created pointing to a `.tar.gz` file

**Step 2: Load the image into Docker**

Run: `docker load < result`
Expected: Output like `Loaded image: ghcr.io/jordangarrison/greenlight:latest`

**Step 3: Verify the image runs**

Run:
```bash
docker run --rm -p 4000:4000 \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e GITHUB_TOKEN="test" \
  -e PHX_HOST="localhost" \
  ghcr.io/jordangarrison/greenlight:latest
```
Expected: Phoenix server starts on port 4000. Ctrl+C to stop.

**Step 4: Inspect image size**

Run: `docker images ghcr.io/jordangarrison/greenlight`
Expected: Image size displayed (should be relatively small due to layered build with no shell/package manager)

---

### Task 4: Update README with container usage

**Files:**
- Modify: `README.md`

**Step 1: Add container section to README**

Add a "Container" or "Docker" section to the README documenting:
- How to build: `nix build .#dockerImage`
- How to load: `docker load < result`
- How to run with required env vars
- List of required and optional environment variables

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add container build and run instructions to README"
```
