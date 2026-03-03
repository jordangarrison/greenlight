# Ash Declarative Data Layer Design

**Date:** 2026-03-03
**Branch:** onboard-ash
**Status:** Design

## Goal

Replace the hand-rolled GitHub API client pattern (plain structs + `GitHub.Client` calls scattered through GenServers and LiveViews) with Ash Framework's declarative resource model. Every piece of data in the system becomes a typed Ash resource with attributes, actions, and relationships. All callers go through a single `Greenlight.GitHub` domain interface.

## Why Ash

- **Declarative data modeling** — Resources define attributes, types, relationships, and validations in one place
- **Uniform interface** — Every caller uses the same domain API (`Greenlight.GitHub.list_workflow_runs!("owner", "repo")`)
- **Composable loading** — `Ash.load!(runs, [jobs: [:steps]])` replaces manual multi-step fetch orchestration
- **Evolvability** — Future API integrations (other CI providers, artifact stores, etc.) follow the same resource pattern
- **Ecosystem** — Ash resources can later be exposed via AshJsonApi, AshGraphql, etc. if needed

## Approach

Use **manual actions** (`Ash.Resource.ManualRead`) — the officially recommended pattern for wrapping external APIs. Each resource defines read actions backed by manual modules that call the existing `GitHub.Client` HTTP layer. No custom data layer implementation needed.

## Domain & Resources

### Domain: `Greenlight.GitHub`

The Ash Domain groups all resources and defines the public code interface. No LiveView, GenServer, or other consumer should call `GitHub.Client` directly — everything goes through the domain.

### Resource Overview

| Resource | File | Replaces | Relationships |
|---|---|---|---|
| `Greenlight.GitHub.WorkflowRun` | `workflow_run.ex` | `Models.WorkflowRun` | has_many :jobs |
| `Greenlight.GitHub.Job` | `job.ex` | `Models.Job` | has_many :steps (embedded) |
| `Greenlight.GitHub.Step` | `step.ex` | `Models.Step` (embedded resource) | — |
| `Greenlight.GitHub.Repository` | `repository.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.Pull` | `pull.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.Branch` | `branch.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.Release` | `release.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.User` | `user.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.UserPR` | `user_pr.ex` | ad-hoc maps | — |
| `Greenlight.GitHub.UserCommit` | `user_commit.ex` | ad-hoc maps | — |

### Resource Definitions

#### WorkflowRun

The central resource. `owner` and `repo` are set during the manual read action (not from the GitHub API response) so that relationship loading has the context to make follow-up API calls.

```
attributes:
  id          :integer    primary_key
  name        :string
  workflow_id :integer
  status      :atom
  conclusion  :atom
  head_sha    :string
  event       :string
  html_url    :string
  path        :string
  created_at  :utc_datetime
  updated_at  :utc_datetime
  owner       :string     (set by action, not from API)
  repo        :string     (set by action, not from API)

actions:
  read :list   — ManualRead, args: [owner, repo], opts: [head_sha, event, per_page]
  read :get    — ManualRead, args: [owner, repo, run_id], get?: true

relationships:
  has_many :jobs, Job — manual relationship using owner/repo/id to fetch
```

#### Job

Loaded via relationship from WorkflowRun or standalone action. `needs` is a plain list attribute populated post-fetch by WorkflowGraph YAML resolution.

```
attributes:
  id            :integer    primary_key
  name          :string
  status        :atom
  conclusion    :atom
  started_at    :utc_datetime
  completed_at  :utc_datetime
  current_step  :string
  html_url      :string
  needs         {:array, :string}
  owner         :string     (set by action)
  repo          :string     (set by action)
  run_id        :integer

actions:
  read :list   — ManualRead, args: [owner, repo, run_id]

relationships:
  has_many :steps, Step — embedded from API response (not a separate call)
```

#### Step (Embedded Resource)

Always comes embedded in the Job API response, never fetched independently.

```
attributes:
  name         :string
  status       :atom
  conclusion   :atom
  number       :integer
  started_at   :utc_datetime
  completed_at :utc_datetime
```

#### Repository

```
attributes:
  full_name  :string    primary_key
  name       :string
  owner      :string
  pushed_at  :utc_datetime

actions:
  read :list_for_org — ManualRead, args: [org]
```

#### Pull

```
attributes:
  number    :integer    primary_key
  title     :string
  head_sha  :string
  state     :string
  html_url  :string

actions:
  read :list — ManualRead, args: [owner, repo]
```

#### Branch

```
attributes:
  name  :string    primary_key
  sha   :string

actions:
  read :list — ManualRead, args: [owner, repo]
```

#### Release

```
attributes:
  tag_name  :string    primary_key
  name      :string
  html_url  :string

actions:
  read :list — ManualRead, args: [owner, repo]
```

#### User

```
attributes:
  login       :string    primary_key
  name        :string
  avatar_url  :string

actions:
  read :me — ManualRead (no args, fetches authenticated user)
```

#### UserPR

```
attributes:
  number      :integer
  title       :string
  state       :string
  html_url    :string    primary_key
  updated_at  :string
  repo        :string

actions:
  read :list — ManualRead, args: [username]
```

#### UserCommit

```
attributes:
  sha         :string    primary_key
  message     :string
  repo        :string
  html_url    :string
  authored_at :string

actions:
  read :list — ManualRead, args: [username]
```

## Domain Code Interface

```elixir
defmodule Greenlight.GitHub do
  use Ash.Domain

  resources do
    resource Greenlight.GitHub.WorkflowRun do
      define :list_workflow_runs, action: :list, args: [:owner, :repo]
      define :get_workflow_run, action: :get, args: [:owner, :repo, :run_id]
    end

    resource Greenlight.GitHub.Job do
      define :list_jobs, action: :list, args: [:owner, :repo, :run_id]
    end

    resource Greenlight.GitHub.Repository do
      define :list_org_repos, action: :list_for_org, args: [:org]
    end

    resource Greenlight.GitHub.Pull do
      define :list_pulls, action: :list, args: [:owner, :repo]
    end

    resource Greenlight.GitHub.Branch do
      define :list_branches, action: :list, args: [:owner, :repo]
    end

    resource Greenlight.GitHub.Release do
      define :list_releases, action: :list, args: [:owner, :repo]
    end

    resource Greenlight.GitHub.User do
      define :get_authenticated_user, action: :me
    end

    resource Greenlight.GitHub.UserPR do
      define :list_user_prs, action: :list, args: [:username]
    end

    resource Greenlight.GitHub.UserCommit do
      define :list_user_commits, action: :list, args: [:username]
    end
  end
end
```

## Manual Action Pattern

Each resource's read action delegates to a ManualRead module under `lib/greenlight/github/actions/`. These modules call the existing `GitHub.Client` functions and map responses to Ash resource structs.

Example for WorkflowRun:

```elixir
defmodule Greenlight.GitHub.Actions.ListWorkflowRuns do
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.{Client, WorkflowRun}

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    opts =
      query.arguments
      |> Map.take([:head_sha, :event, :per_page])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case Client.list_workflow_runs(owner, repo, opts) do
      {:ok, api_runs} ->
        resources = Enum.map(api_runs, &to_resource(&1, owner, repo))
        {:ok, resources}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(api_data, owner, repo) do
    # Map from raw API response to Ash resource struct
    # Client.list_workflow_runs currently returns Models.WorkflowRun structs,
    # so we'll update Client to return raw maps and do the mapping here,
    # OR have Client return Ash resource structs directly
    %WorkflowRun{
      id: api_data.id,
      name: api_data.name,
      workflow_id: api_data.workflow_id,
      status: api_data.status,
      conclusion: api_data.conclusion,
      head_sha: api_data.head_sha,
      event: api_data.event,
      html_url: api_data.html_url,
      path: api_data.path,
      created_at: api_data.created_at,
      updated_at: api_data.updated_at,
      owner: owner,
      repo: repo
    }
  end
end
```

## Consumer Changes

### Poller (GenServer — stays, but thinner)

```elixir
# Before
{:ok, runs} = Client.list_workflow_runs(owner, repo, head_sha: ref)
runs = fetch_jobs_for_runs(runs, owner, repo)
{runs, workflow_defs} = resolve_all_job_needs(runs, owner, repo, workflow_defs)

# After
runs = Greenlight.GitHub.list_workflow_runs!(owner, repo)
runs = Ash.load!(runs, [:jobs])
# YAML resolution stays (post-processing, not an API fetch pattern)
{runs, workflow_defs} = resolve_all_job_needs(runs, owner, repo, workflow_defs)
```

The Poller retains ownership of: polling interval, subscriber lifecycle, PubSub broadcasting, YAML resolution caching.

### UserInsightsServer (GenServer — stays, simpler)

```elixir
# Before
{:ok, user} = Client.get_authenticated_user()
{:ok, prs} = Client.search_user_prs(user.login)
{:ok, commits} = Client.search_user_commits(user.login)

# After
user = Greenlight.GitHub.get_authenticated_user!()
prs = Greenlight.GitHub.list_user_prs!(user.login)
commits = Greenlight.GitHub.list_user_commits!(user.login)
```

### LiveViews

All `Client.*` calls replaced with `Greenlight.GitHub.*` domain calls:
- `PipelineLive` — `list_pulls`, `list_workflow_runs` for PR/release route resolution
- `DashboardLive` — `list_org_repos`
- `RepoLive` — `list_pulls`, `list_branches`, `list_releases`, `list_workflow_runs`

### WorkflowGraph

Update struct pattern matches from `%Models.WorkflowRun{}` / `%Models.Job{}` / `%Models.Step{}` to the new Ash resource module names. Function signatures and logic remain the same.

## File Layout

### New files

```
lib/greenlight/github/
  domain.ex                          # Greenlight.GitHub (Ash Domain)
  workflow_run.ex                    # Ash Resource
  job.ex                             # Ash Resource
  step.ex                            # Ash Resource (embedded)
  repository.ex                      # Ash Resource
  pull.ex                            # Ash Resource
  branch.ex                          # Ash Resource
  release.ex                         # Ash Resource
  user.ex                            # Ash Resource
  user_pr.ex                         # Ash Resource
  user_commit.ex                     # Ash Resource
  actions/
    list_workflow_runs.ex            # ManualRead
    get_workflow_run.ex              # ManualRead
    list_jobs.ex                     # ManualRead
    list_org_repos.ex                # ManualRead
    list_pulls.ex                    # ManualRead
    list_branches.ex                 # ManualRead
    list_releases.ex                 # ManualRead
    get_authenticated_user.ex        # ManualRead
    list_user_prs.ex                 # ManualRead
    list_user_commits.ex             # ManualRead
```

### Files to modify

- `mix.exs` — add `{:ash, "~> 3.19"}`
- `config/config.exs` — add Ash domain config: `config :greenlight, ash_domains: [Greenlight.GitHub]`
- `nix/package.nix` — update dep hash after adding ash
- `poller.ex` — replace Client calls with domain calls + Ash.load!
- `user_insights_server.ex` — replace Client calls with domain calls
- `pipeline_live.ex` — replace Client calls with domain calls
- `dashboard_live.ex` — replace Client calls with domain calls
- `repo_live.ex` — replace Client calls with domain calls
- `workflow_graph.ex` — update struct references from Models.* to Ash resources
- `client.ex` — update to return raw maps instead of Models structs (ManualRead modules handle struct mapping)
- `application.ex` — no changes needed (Ash domains don't need supervision)

### Files to delete

- `lib/greenlight/github/models.ex` — fully replaced by Ash resources

## Client Migration Strategy

The `GitHub.Client` module currently returns `Models.*` structs via `from_api/1`. Two options:

1. **Client returns raw maps** — ManualRead modules handle all mapping. Client becomes a pure HTTP layer.
2. **Client returns Ash resource structs** — Update `from_api/1` to construct Ash resource structs instead.

**Recommendation: Option 1.** The Client should be a dumb HTTP layer. Struct construction belongs in the Ash action layer. This keeps concerns cleanly separated and means the Client has no dependency on Ash.

## Dependencies

- `{:ash, "~> 3.19"}` — the only new dependency
- No database, no Ecto, no AshPostgres needed
- Spark (Ash's DSL engine) comes as a transitive dep

## Testing Strategy

- Existing `Req.Test` plug-based mocking continues to work since ManualRead modules call Client, which uses Req
- Tests can also call domain functions directly: `Greenlight.GitHub.list_workflow_runs!("owner", "repo")`
- Ash provides `Ash.Test` utilities if needed for more advanced testing scenarios

## Non-Goals

- No database/persistence layer (stays in-memory)
- No AshJsonApi/AshGraphql (can be added later)
- No AshAuthentication (GitHub token stays as env var config)
- GenServers (Poller, UserInsightsServer) keep their OTP orchestration role
