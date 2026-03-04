# Release-Please & Docker Publishing Pipeline Design

**Date:** 2026-03-03
**Status:** Draft

## Goals

- Automated semantic versioning via release-please based on conventional commits
- Automated CHANGELOG.md generation
- GitHub Releases with release notes on each version bump
- Semantic version tags on Docker images (`latest` + `vX.Y.Z`) on release
- Continuous `edge` builds from main for bleeding-edge users
- PR title validation to enforce conventional commits

## Architecture

```
Push to main
  ├── CI workflow (existing, modified)
  │   ├── test
  │   ├── nix build
  │   └── deploy → push Docker as `edge` + SHA
  │
  └── Release-please workflow (new)
      └── Creates/updates release PR with changelog + version bump
          │
          └── On merge → GitHub Release + v* tag
                │
                └── Publish workflow (new, triggered by release)
                    └── push Docker as `latest` + `vX.Y.Z`
```

## Docker Image Tagging Strategy

| Trigger | Tags | Purpose |
|---------|------|---------|
| Push to main | `edge`, `<short-sha>` | Bleeding edge, continuous deployment |
| Release published | `latest`, `vX.Y.Z` | Stable release for end users |

## File Changes

### New Files

#### `.release-please-config.json`

- Release type: `simple`
- v-prefixed tags (`v0.2.0`)
- PR title pattern: `Release: ${version}`
- All conventional commit types mapped to changelog sections
- `extra-files` to update version in `mix.exs` and `nix/package.nix`

#### `.release-please-manifest.json`

- Starting version: `{ ".": "0.1.0" }`

#### `.github/workflows/release-please.yml`

- Trigger: push to main
- Uses `googleapis/release-please-action@v4`
- Uses `GITHUB_TOKEN` (PAT not needed — publish triggers on `release` event)
- Concurrency group, no cancel-in-progress

#### `.github/workflows/publish.yml`

- Trigger: `on: release: types: [published]`
- Steps: checkout, install nix, build docker image, login to GHCR, push with `latest` + version tag
- Extracts version from release tag name

#### `.github/workflows/check-pr-title.yml`

- Trigger: PR opened/edited/reopened/synchronize
- Uses `amannn/action-semantic-pull-request@v6`
- Skips release-please PRs (title starts with "Release:")

### Modified Files

#### `.github/workflows/ci.yml`

- Deploy job: change `latest` tag to `edge`
- Keep SHA tag as-is

#### `mix.exs` (by release-please)

- Version string updated automatically on release

#### `nix/package.nix` (by release-please)

- Version string updated automatically on release

## Token Strategy

Using `GITHUB_TOKEN` (not a PAT) because:
- The publish workflow triggers on `release` events, not `push` events
- `GITHUB_TOKEN` can create releases and tags
- No need for a PAT to trigger downstream workflows since we use event-based triggering

## Version Bump Rules

| Commit Type | Version Bump |
|-------------|-------------|
| `feat:` | Minor (0.x.0) |
| `fix:` | Patch (0.0.x) |
| `feat!:` / `BREAKING CHANGE` | Major (x.0.0) |
| `chore:`, `docs:`, `ci:`, etc. | Patch |
