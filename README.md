# Greenlight

A GitHub Actions workflow visualizer built with Phoenix LiveView. View your CI/CD pipelines as interactive DAGs, drill down from workflow-level to individual jobs, and track runs across organizations and repositories.

![Greenlight Demo](docs/assets/greenlight-demo.gif)

## Features

- **Interactive DAG visualization** of GitHub Actions workflows using Svelte Flow
- **Real-time polling** of workflow run status
- **Expandable job nodes** — click a workflow to see its jobs and dependency graph
- **Dashboard** for followed organizations and bookmarked repositories
- **Repository browser** with workflow run history
- **Pipeline view** per commit with dependency resolution from workflow YAML

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) ~> 1.15
- [Node.js](https://nodejs.org/) (for asset compilation)
- A [GitHub Personal Access Token](https://github.com/settings/tokens) with `repo` and `actions` read access
- (Optional) [Nix](https://nixos.org/) with flakes enabled — the repo includes a `flake.nix` for a reproducible dev environment

## Setup

Clone the repo and install dependencies:

```bash
git clone https://github.com/jordangarrison/greenlight.git
cd greenlight
mix setup
```

If you use Nix and direnv, the dev environment loads automatically. Otherwise, make sure Elixir and Node.js are installed.

## Configuration

Create a `.env` file in the project root:

```bash
export GITHUB_TOKEN="your_github_token"
export GREENLIGHT_BOOKMARKED_REPOS="owner/repo1,owner/repo2"
export GREENLIGHT_FOLLOWED_ORGS="my-org,another-org"
```

If you use direnv, these will be loaded automatically via `.envrc`. Otherwise, source the file before starting the server:

```bash
source .env
```

| Variable | Required | Description |
|---|---|---|
| `GITHUB_TOKEN` | Yes | GitHub PAT with `repo` and `actions` read access |
| `GREENLIGHT_BOOKMARKED_REPOS` | No | Comma-separated list of `owner/repo` to pin on the dashboard |
| `GREENLIGHT_FOLLOWED_ORGS` | No | Comma-separated list of GitHub orgs to follow |

## Running

```bash
mix phx.server
```

Then visit [localhost:4000](http://localhost:4000).

## Development

```bash
# Run the formatter, compiler warnings check, and tests
mix precommit

# Run tests only
mix test
```

## Container

Build a Docker image using Nix (requires [Nix](https://nixos.org/) with flakes enabled):

```bash
nix build .#dockerImage
docker load < result
```

Run the container with the required environment variables:

```bash
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e GITHUB_TOKEN="your_github_token" \
  -e PHX_HOST="localhost" \
  ghcr.io/jordangarrison/greenlight:latest
```

Then visit [localhost:4000](http://localhost:4000).

| Variable | Required | Description |
|---|---|---|
| `SECRET_KEY_BASE` | Yes | Phoenix session signing key (generate with `mix phx.gen.secret`) |
| `GITHUB_TOKEN` | Yes | GitHub PAT with `repo` and `actions` read access |
| `PHX_HOST` | Yes | Public hostname for URL generation |
| `PORT` | No | HTTP listen port (default: `4000`) |
| `GREENLIGHT_LISTEN_ADDRESS` | No | Bind address (default: `0.0.0.0` in container) |
| `GREENLIGHT_BOOKMARKED_REPOS` | No | Comma-separated list of `owner/repo` to pin |
| `GREENLIGHT_FOLLOWED_ORGS` | No | Comma-separated list of GitHub orgs to follow |

## License

MIT — see [LICENSE](LICENSE).
