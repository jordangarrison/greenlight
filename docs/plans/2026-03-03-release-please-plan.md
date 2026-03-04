# Release-Please & Docker Publishing Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automated semantic versioning, changelog generation, and version-tagged Docker image publishing via release-please.

**Architecture:** Release-please watches main for conventional commits, creates release PRs with changelog/version bumps, and on merge creates GitHub Releases that trigger a publish workflow pushing Docker images tagged with the semantic version. The existing CI deploy job switches from `latest` to `edge` for continuous main builds.

**Tech Stack:** GitHub Actions, googleapis/release-please-action@v4, amannn/action-semantic-pull-request@v6, Nix Docker builds, GHCR

---

### Task 1: Add release-please config and manifest

**Files:**
- Create: `.release-please-config.json`
- Create: `.release-please-manifest.json`

**Step 1: Create `.release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "pull-request-title-pattern": "Release: ${version}",
      "pull-request-header": ":rocket: Merging this PR will create a new release",
      "changelog-path": "CHANGELOG.md",
      "changelog-sections": [
        { "type": "feat", "section": "Features", "hidden": false },
        { "type": "fix", "section": "Bug Fixes", "hidden": false },
        { "type": "perf", "section": "Performance Improvements", "hidden": false },
        { "type": "revert", "section": "Reverts", "hidden": false },
        { "type": "docs", "section": "Documentation", "hidden": false },
        { "type": "style", "section": "Styles", "hidden": false },
        { "type": "chore", "section": "Miscellaneous Chores", "hidden": false },
        { "type": "refactor", "section": "Code Refactoring", "hidden": false },
        { "type": "test", "section": "Tests", "hidden": false },
        { "type": "build", "section": "Build System", "hidden": false },
        { "type": "ci", "section": "Continuous Integration", "hidden": false }
      ],
      "bump-minor-pre-major": false,
      "bump-patch-for-minor-pre-major": false,
      "draft": false,
      "prerelease": false,
      "include-v-in-tag": true,
      "include-component-in-tag": false,
      "extra-files": [
        {
          "type": "generic",
          "path": "mix.exs"
        },
        {
          "type": "generic",
          "path": "nix/package.nix"
        }
      ]
    }
  }
}
```

**Step 2: Create `.release-please-manifest.json`**

```json
{
  ".": "0.1.0"
}
```

**Step 3: Commit**

```bash
git add .release-please-config.json .release-please-manifest.json
git commit -m "ci: add release-please config and manifest"
```

---

### Task 2: Add version annotations to source files

The generic updater in release-please looks for `x-release-please-version` annotations in comments to know which lines to update.

**Files:**
- Modify: `mix.exs:7` — add annotation comment
- Modify: `nix/package.nix:13` — add annotation comment

**Step 1: Add annotation to `mix.exs`**

Change line 7 from:
```elixir
      version: "0.1.0",
```
to:
```elixir
      version: "0.1.0", # x-release-please-version
```

**Step 2: Add annotation to `nix/package.nix`**

Change line 13 from:
```nix
  version = "0.1.0";
```
to:
```nix
  version = "0.1.0"; # x-release-please-version
```

**Step 3: Verify the project still builds**

Run: `nix build .#default`
Expected: Success (the comment doesn't affect Nix evaluation)

**Step 4: Commit**

```bash
git add mix.exs nix/package.nix
git commit -m "ci: add release-please version annotations to mix.exs and package.nix"
```

---

### Task 3: Create release-please workflow

**Files:**
- Create: `.github/workflows/release-please.yml`

**Step 1: Create the workflow file**

```yaml
name: Release Please

on:
  push:
    branches:
      - main

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          config-file: .release-please-config.json
          manifest-file: .release-please-manifest.json
```

**Notes:**
- Uses `GITHUB_TOKEN` implicitly (no `token:` needed, it's the default)
- `contents: write` is needed to create tags and releases
- `pull-requests: write` is needed to create/update the release PR
- `cancel-in-progress: false` so concurrent pushes don't cancel an in-flight release

**Step 2: Commit**

```bash
git add .github/workflows/release-please.yml
git commit -m "ci: add release-please workflow"
```

---

### Task 4: Create publish-on-release workflow

**Files:**
- Create: `.github/workflows/publish.yml`

**Step 1: Create the workflow file**

```yaml
name: Publish Release

on:
  release:
    types: [published]

jobs:
  publish:
    name: Build & Push Release Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/nix-installer-action@v21
      - uses: DeterminateSystems/magic-nix-cache-action@v13
      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build container image
        run: nix build .#dockerImage
      - name: Push release image
        run: |
          set -euo pipefail
          docker load < ./result
          VERSION="${GITHUB_REF_NAME}"
          docker tag ghcr.io/jordangarrison/greenlight:latest "ghcr.io/jordangarrison/greenlight:${VERSION}"
          docker push ghcr.io/jordangarrison/greenlight:latest
          docker push "ghcr.io/jordangarrison/greenlight:${VERSION}"
```

**Notes:**
- `GITHUB_REF_NAME` will be the tag name (e.g., `v0.2.0`) when triggered by a release
- Pushes both `latest` (stable) and versioned tag

**Step 2: Commit**

```bash
git add .github/workflows/publish.yml
git commit -m "ci: add publish workflow for release Docker images"
```

---

### Task 5: Update CI deploy job to use `edge` tag

**Files:**
- Modify: `.github/workflows/ci.yml:66-72` — change `latest` to `edge`

**Step 1: Update the deploy job**

Change the "Load and push container image" step from:
```yaml
      - name: Load and push container image
        run: |
          set -euo pipefail
          docker load < ./result
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          docker tag ghcr.io/jordangarrison/greenlight:latest "ghcr.io/jordangarrison/greenlight:${SHORT_SHA}"
          docker push ghcr.io/jordangarrison/greenlight:latest
          docker push "ghcr.io/jordangarrison/greenlight:${SHORT_SHA}"
```

to:
```yaml
      - name: Load and push container image
        run: |
          set -euo pipefail
          docker load < ./result
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          docker tag ghcr.io/jordangarrison/greenlight:latest "ghcr.io/jordangarrison/greenlight:edge"
          docker tag ghcr.io/jordangarrison/greenlight:latest "ghcr.io/jordangarrison/greenlight:${SHORT_SHA}"
          docker push ghcr.io/jordangarrison/greenlight:edge
          docker push "ghcr.io/jordangarrison/greenlight:${SHORT_SHA}"
```

**Notes:**
- Nix builds the image as `latest` locally (hardcoded in `nix/docker.nix`), so we retag to `edge` before pushing
- SHA tag preserved for traceability

**Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: tag main branch Docker images as edge instead of latest"
```

---

### Task 6: Add PR title validation workflow

**Files:**
- Create: `.github/workflows/check-pr-title.yml`

**Step 1: Create the workflow file**

```yaml
name: Check PR Title

on:
  pull_request:
    types:
      - opened
      - edited
      - reopened
      - synchronize

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  conventional-pr-title:
    if: startsWith(github.event.pull_request.title, 'Release:') == false
    runs-on: ubuntu-latest
    permissions:
      pull-requests: read
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Notes:**
- Skips release-please PRs (titles start with "Release:")
- Validates all other PR titles follow conventional commit format
- `pull-requests: read` is sufficient for validation

**Step 2: Commit**

```bash
git add .github/workflows/check-pr-title.yml
git commit -m "ci: add PR title conventional commit validation"
```

---

### Task 7: Final review and push

**Step 1: Verify all files are committed**

Run: `git status`
Expected: Clean working tree

**Step 2: Review the full diff**

Run: `git log --oneline main..HEAD`
Expected: 6 commits covering all tasks

**Step 3: Push the branch**

Run: `git push -u origin release-please`

**Step 4: Create PR**

Create a PR to main with the changes.
