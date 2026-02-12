# GitHub Actions DAG Viewer — Design Document

## Problem

GitHub Actions has no unified view of all workflows running for a given ref (commit, PR, release). You have to click into each workflow file individually. For repos with multiple workflows that depend on each other, there's no way to see the full pipeline at a glance.

## Solution

A Phoenix LiveView app that shows all GitHub Actions workflow runs for a selected ref as an interactive DAG (directed acyclic graph). Two levels of detail:

1. **Workflow-level DAG** — each node is a workflow (e.g., CI, Deploy), edges show cross-workflow dependencies (`workflow_run` triggers)
2. **Job-level DAG** — drill into a workflow to see its jobs as nodes, edges from `needs:` dependencies

## Stack

- **Phoenix LiveView** — state management, polling orchestration, routing
- **LiveSvelte** (`~> 0.17`) — bridges LiveView assigns to Svelte component props
- **Svelte Flow** (`@xyflow/svelte`) — interactive DAG rendering with custom node components
- **Dagre** — automatic DAG layout computation
- **Req** — HTTP client for GitHub API
- **libgraph** (`~> 0.16`) — server-side graph construction and topological sorting

## Architecture

```
GitHub API (REST v3)
       | (polling every 10-60s)
GenServer (per-ref poller)
       | (PubSub broadcast)
LiveView process
       | (assigns -> props)
LiveSvelte <.svelte> component
       | (nodes/edges as props)
Svelte Flow + Dagre layout
       | (user clicks node)
live.pushEvent -> LiveView handle_event
```

No database for v1. Everything is fetched from GitHub and held in memory by poller GenServers.

## GitHub API Strategy

### Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /orgs/{org}/repos` | List repos for followed orgs |
| `GET /repos/{owner}/{repo}/actions/runs` | List workflow runs (filterable by branch/event/status) |
| `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` | Jobs within a run (includes steps, timing, status) |
| `GET /repos/{owner}/{repo}/pulls` | Open PRs for the PR tab |
| `GET /repos/{owner}/{repo}/branches` | Branches for the branch tab |
| `GET /repos/{owner}/{repo}/releases` | Releases for the release tab |

### Authentication

Personal Access Token (PAT) via environment variable. 5,000 requests/hour rate limit.

### Rate Limit Budget

For a ref that triggered 5 workflows: 6 calls per poll cycle (1 for runs + 5 for jobs). At 30s polling, ~720 calls/hour per active view. Manageable for personal use.

## Data Model

Elixir structs (not Ecto — no database):

```elixir
%WorkflowRun{
  id: integer,
  name: string,            # "CI" or "Deploy"
  workflow_id: integer,
  status: atom,            # :queued | :in_progress | :completed
  conclusion: atom,        # :success | :failure | :cancelled | nil
  head_sha: string,
  event: string,           # "push" | "pull_request" | "release"
  html_url: string,        # link to GitHub
  created_at: DateTime,
  updated_at: DateTime,
  jobs: [Job]
}

%Job{
  id: integer,
  name: string,
  status: atom,
  conclusion: atom,
  started_at: DateTime,
  completed_at: DateTime,
  current_step: string,    # name of currently executing step
  html_url: string,        # link to GitHub job logs
  steps: [Step]
}

%Step{
  name: string,
  status: atom,
  conclusion: atom,
  number: integer,
  started_at: DateTime,
  completed_at: DateTime
}
```

### Building the DAG

Edges come from two sources:

1. **Job-level `needs:`** — GitHub's jobs API returns this directly, maps to edges within a workflow
2. **Workflow-level `workflow_run` triggers** — detected by matching `event: "workflow_run"` runs and correlating by SHA/timing

## Poller Architecture

### On-Demand Polling

Pollers only run while someone is actively viewing a ref. No background polling.

```
DynamicSupervisor (Greenlight.PollerSupervisor)
  +-- Poller GenServer (org/repo + sha_abc123)
  +-- Poller GenServer (org/repo + sha_def456)
  +-- ...
```

### Lifecycle

1. User navigates to DAG view, LiveView mounts
2. LiveView calls `Greenlight.Pollers.subscribe(owner, repo, ref)` which:
   - Starts a Poller GenServer if one doesn't exist (via DynamicSupervisor)
   - Subscribes the LiveView to PubSub topic `"pipeline:owner/repo:sha"`
   - Returns current cached state immediately
3. Poller fetches workflow runs + jobs on an interval
4. On each poll, Poller diffs state — broadcasts via PubSub only if anything changed
5. LiveView receives broadcast in `handle_info`, updates assigns, props flow to Svelte
6. When last viewer leaves, Poller shuts down after 60s grace period

### Adaptive Polling Interval

- 10s while any workflow is `:in_progress`
- 60s when everything is `:completed`

### Subscriber Tracking

Poller monitors each subscribed LiveView process. On process down, decrements subscriber count. At zero + grace period elapsed, terminates.

### Path to Webhooks

The PubSub broadcast is the seam. Today the Poller is the producer; later a webhook endpoint can broadcast to the same topic. LiveViews don't care where updates come from.

## URL Structure

```
/                                        -> redirect to /dashboard
/dashboard                               -> org/repo browser, bookmarked repos
/repos/:owner/:repo                      -> ref selector (tabs: PRs, Branches, Releases, Commits)
/repos/:owner/:repo/commit/:sha          -> DAG view for a commit
/repos/:owner/:repo/pull/:number         -> DAG view for a PR's head SHA
/repos/:owner/:repo/release/:tag         -> DAG view for a release tag
```

## UI Design

### Dashboard (`/dashboard`)

- Top section: bookmarked repos as cards with latest run status (green/red/yellow dot)
- Below: followed orgs, expandable to see their repos
- Config-driven for v1 (env vars / config.exs)

### Ref Selector (`/repos/:owner/:repo`)

- Four tabs: **PRs** | **Branches** | **Releases** | **Commits**
- Each tab shows a list with latest workflow status summary
- Click a row to navigate to the DAG view

### DAG View (`/repos/:owner/:repo/commit/:sha`)

- Header: repo name, ref info (branch, PR title, commit message), overall status
- Main area: Svelte Flow canvas
  - Workflow-level: each workflow is a container node (name, status, elapsed time)
  - Click workflow node to drill into job-level DAG
  - Job-level: each job shows name, status, elapsed time, current step, progress bar
  - Right-click or icon on any node opens GitHub logs in new tab (`html_url`)
- Controls: pan, zoom, fit-to-view, minimap
- Auto-updates via polling with animated status transitions

### Status Colors

- Queued: gray
- In progress: amber with pulse animation
- Success: green
- Failure: red
- Cancelled: gray with strikethrough

## Svelte Components

```
assets/svelte/
  DagViewer.svelte              # Top-level Svelte Flow wrapper
  nodes/
    WorkflowNode.svelte         # Custom workflow node (name, status, elapsed, job summary)
    JobNode.svelte              # Custom job node (name, status, elapsed, current step, progress)
  components/
    StatusBadge.svelte          # Reusable status color + pulse
    ProgressBar.svelte          # Step completion progress bar
```

### Data Shape (LiveView -> Svelte)

```javascript
// nodes
[
  { id: "wf-123", type: "workflow", data: { name: "CI", status: "in_progress", elapsed: 142, jobs_passed: 2, jobs_total: 5, html_url: "..." } }
]

// edges
[
  { id: "e-123-456", source: "wf-123", target: "wf-456", animated: true }
]
```

### Events (Svelte -> LiveView)

- `node_clicked` — drill into workflow's job DAG
- `back_clicked` — return to workflow-level view
- `open_github` — open `html_url` in new tab (handled client-side, no server round-trip needed)

## Elixir Module Structure

```
lib/
  greenlight/
    github/
      client.ex                 # Req-based GitHub API wrapper
      poller.ex                 # GenServer: polls and broadcasts
      poller_supervisor.ex      # DynamicSupervisor for pollers
      models.ex                 # WorkflowRun, Job, Step structs
      workflow_graph.ex         # API data -> Svelte Flow nodes/edges
    pollers.ex                  # Public API: subscribe/unsubscribe
  greenlight_web/
    live/
      dashboard_live.ex         # Org/repo browser, bookmarks
      repo_live.ex              # Ref selector with tabs
      pipeline_live.ex          # DAG view, poller subscription
```

## Configuration (v1)

```elixir
config :greenlight,
  github_token: System.get_env("GITHUB_TOKEN"),
  bookmarked_repos: ["owner/repo1", "owner/repo2"],
  followed_orgs: ["my-org", "another-org"]
```

## Dependencies

### mix.exs

```elixir
{:live_svelte, "~> 0.17"},
{:libgraph, "~> 0.16"}
```

### npm (assets/)

```
@xyflow/svelte
dagre
```

## Future Considerations

- **Multi-user support** — GitHub OAuth, per-user config stored in database
- **Webhooks** — replace polling with real-time GitHub webhook events via the same PubSub seam
- **Notifications** — alert on workflow failures
- **Persistence** — store historical run data for trend analysis
