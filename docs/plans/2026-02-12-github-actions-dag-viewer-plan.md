# GitHub Actions DAG Viewer — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Phoenix LiveView app that visualizes GitHub Actions workflow runs as an interactive DAG, with drill-down from workflow-level to job-level views.

**Architecture:** LiveView manages state and polls GitHub API via on-demand GenServer pollers. LiveSvelte bridges assigns to Svelte Flow components that render the DAG with Dagre layout. PubSub decouples pollers from views for future webhook support.

**Tech Stack:** Phoenix 1.8, LiveView 1.1, LiveSvelte 0.17, Svelte Flow (@xyflow/svelte), Dagre, Req, libgraph

**Design Doc:** `docs/plans/2026-02-12-github-actions-dag-viewer-design.md`

---

## Task 1: Add Dependencies and Configure LiveSvelte

**Files:**
- Modify: `mix.exs`
- Modify: `lib/greenlight_web.ex`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `assets/js/app.js`
- Modify: `assets/css/app.css`

**Step 1: Add Elixir deps to mix.exs**

Add `{:live_svelte, "~> 0.17"}` and `{:libgraph, "~> 0.16"}` to the `deps` function:

```elixir
{:live_svelte, "~> 0.17"},
{:libgraph, "~> 0.16"}
```

**Step 2: Update mix.exs aliases**

Replace the `setup` alias to include npm install, and update `assets.deploy` to use LiveSvelte's build.js instead of esbuild:

```elixir
defp aliases do
  [
    setup: ["deps.get", "cmd --cd assets npm install", "assets.setup", "assets.build"],
    "assets.setup": ["tailwind.install --if-missing"],
    "assets.build": ["compile", "tailwind greenlight", "cmd --cd assets node build.js"],
    "assets.deploy": [
      "tailwind greenlight --minify",
      "cmd --cd assets node build.js --deploy",
      "phx.digest"
    ],
    precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
  ]
end
```

**Step 3: Fetch deps and run LiveSvelte setup**

Run: `mix deps.get && mix live_svelte.setup`

This generates `assets/build.js`, `assets/package.json` (or updates it), and `assets/svelte/` directory.

**Step 4: Install npm dependencies**

Run: `cd assets && npm install @xyflow/svelte dagre && cd ..`

**Step 5: Remove esbuild config from config.exs**

Remove the entire `config :esbuild, ...` block from `config/config.exs`. LiveSvelte uses its own `build.js` instead of the hex esbuild package.

Also remove `{:esbuild, "~> 0.10", runtime: Mix.env() == :dev}` from the deps in `mix.exs`.

**Step 6: Update dev.exs watchers**

Replace the esbuild watcher with LiveSvelte's node-based watcher in `config/dev.exs`:

```elixir
watchers: [
  esbuild: {LiveSvelte, :watch, [:greenlight]},
  tailwind: {Tailwind, :install_and_run, [:greenlight, ~w(--watch)]}
]
```

**Step 7: Import LiveSvelte in greenlight_web.ex**

Add `import LiveSvelte` to the `html_helpers` function in `lib/greenlight_web.ex`:

```elixir
defp html_helpers do
  quote do
    use Gettext, backend: GreenlightWeb.Gettext
    import Phoenix.HTML
    import GreenlightWeb.CoreComponents
    import LiveSvelte

    alias Phoenix.LiveView.JS
    alias GreenlightWeb.Layouts

    unquote(verified_routes())
  end
end
```

**Step 8: Add Svelte source to Tailwind**

Add `@source "../svelte";` to `assets/css/app.css` after the existing `@source` lines:

```css
@source "../svelte";
```

**Step 9: Verify the build works**

Run: `mix setup && mix phx.server`

Expected: Server starts without errors. Visit `http://localhost:4000` — the default Phoenix page loads.

**Step 10: Create a smoke-test Svelte component**

Create `assets/svelte/Hello.svelte`:

```svelte
<script>
  export let name = "World"
</script>

<p>Hello {name} from Svelte!</p>
```

Create a temporary LiveView at `lib/greenlight_web/live/test_live.ex`:

```elixir
defmodule GreenlightWeb.TestLive do
  use GreenlightWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, name: "Greenlight")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.svelte name="Hello" props={%{name: @name}} socket={@socket} />
    </Layouts.app>
    """
  end
end
```

Add a route in `router.ex` inside the browser scope:

```elixir
live "/test", TestLive
```

Run: `mix phx.server`

Visit `http://localhost:4000/test` — should see "Hello Greenlight from Svelte!".

**Step 11: Commit**

```bash
git add -A
git commit -m "feat: add LiveSvelte, libgraph, and Svelte Flow dependencies"
```

---

## Task 2: Configuration and Application Setup

**Files:**
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`
- Modify: `lib/greenlight/application.ex`
- Create: `lib/greenlight/config.ex`

**Step 1: Add app config to config.exs**

Add to the bottom of `config/config.exs` (above the `import_config` line):

```elixir
config :greenlight,
  github_token: System.get_env("GITHUB_TOKEN"),
  bookmarked_repos: [],
  followed_orgs: []
```

**Step 2: Add runtime config for GitHub token**

Add to `config/runtime.exs` (outside the `if config_env() == :prod` block):

```elixir
config :greenlight,
  github_token: System.get_env("GITHUB_TOKEN"),
  bookmarked_repos:
    System.get_env("GREENLIGHT_BOOKMARKED_REPOS", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1),
  followed_orgs:
    System.get_env("GREENLIGHT_FOLLOWED_ORGS", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
```

**Step 3: Create config helper module**

Create `lib/greenlight/config.ex`:

```elixir
defmodule Greenlight.Config do
  @moduledoc """
  Application configuration helpers.
  """

  def github_token do
    Application.get_env(:greenlight, :github_token) ||
      raise "GITHUB_TOKEN environment variable is not set"
  end

  def bookmarked_repos do
    Application.get_env(:greenlight, :bookmarked_repos, [])
  end

  def followed_orgs do
    Application.get_env(:greenlight, :followed_orgs, [])
  end
end
```

**Step 4: Add DynamicSupervisor to the supervision tree**

Update `lib/greenlight/application.ex` to add the poller supervisor:

```elixir
children = [
  GreenlightWeb.Telemetry,
  {DNSCluster, query: Application.get_env(:greenlight, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: Greenlight.PubSub},
  {DynamicSupervisor, name: Greenlight.PollerSupervisor, strategy: :one_for_one},
  GreenlightWeb.Endpoint
]
```

**Step 5: Verify it compiles**

Run: `mix compile`

Expected: No errors.

**Step 6: Commit**

```bash
git add lib/greenlight/config.ex lib/greenlight/application.ex config/config.exs config/runtime.exs
git commit -m "feat: add greenlight config, poller supervisor to application tree"
```

---

## Task 3: GitHub API Data Models

**Files:**
- Create: `lib/greenlight/github/models.ex`
- Create: `test/greenlight/github/models_test.exs`

**Step 1: Write test for model parsing**

Create `test/greenlight/github/models_test.exs`:

```elixir
defmodule Greenlight.GitHub.ModelsTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Models

  describe "WorkflowRun.from_api/1" do
    test "parses a GitHub API workflow run response" do
      api_response = %{
        "id" => 123,
        "name" => "CI",
        "workflow_id" => 456,
        "status" => "in_progress",
        "conclusion" => nil,
        "head_sha" => "abc123",
        "event" => "push",
        "html_url" => "https://github.com/owner/repo/actions/runs/123",
        "created_at" => "2026-02-12T10:00:00Z",
        "updated_at" => "2026-02-12T10:01:00Z"
      }

      run = Models.WorkflowRun.from_api(api_response)

      assert run.id == 123
      assert run.name == "CI"
      assert run.status == :in_progress
      assert run.conclusion == nil
      assert run.head_sha == "abc123"
      assert run.event == "push"
      assert run.html_url == "https://github.com/owner/repo/actions/runs/123"
      assert run.jobs == []
    end
  end

  describe "Job.from_api/1" do
    test "parses a GitHub API job response" do
      api_response = %{
        "id" => 789,
        "name" => "build",
        "status" => "completed",
        "conclusion" => "success",
        "started_at" => "2026-02-12T10:00:00Z",
        "completed_at" => "2026-02-12T10:02:30Z",
        "html_url" => "https://github.com/owner/repo/actions/runs/123/job/789",
        "steps" => [
          %{
            "name" => "Checkout",
            "status" => "completed",
            "conclusion" => "success",
            "number" => 1,
            "started_at" => "2026-02-12T10:00:00Z",
            "completed_at" => "2026-02-12T10:00:10Z"
          },
          %{
            "name" => "Run tests",
            "status" => "completed",
            "conclusion" => "success",
            "number" => 2,
            "started_at" => "2026-02-12T10:00:10Z",
            "completed_at" => "2026-02-12T10:02:30Z"
          }
        ]
      }

      job = Models.Job.from_api(api_response)

      assert job.id == 789
      assert job.name == "build"
      assert job.status == :completed
      assert job.conclusion == :success
      assert length(job.steps) == 2
      assert job.current_step == nil
    end

    test "identifies the current step for an in-progress job" do
      api_response = %{
        "id" => 789,
        "name" => "build",
        "status" => "in_progress",
        "conclusion" => nil,
        "started_at" => "2026-02-12T10:00:00Z",
        "completed_at" => nil,
        "html_url" => "https://github.com/owner/repo/actions/runs/123/job/789",
        "steps" => [
          %{
            "name" => "Checkout",
            "status" => "completed",
            "conclusion" => "success",
            "number" => 1,
            "started_at" => "2026-02-12T10:00:00Z",
            "completed_at" => "2026-02-12T10:00:10Z"
          },
          %{
            "name" => "Run tests",
            "status" => "in_progress",
            "conclusion" => nil,
            "number" => 2,
            "started_at" => "2026-02-12T10:00:10Z",
            "completed_at" => nil
          }
        ]
      }

      job = Models.Job.from_api(api_response)

      assert job.current_step == "Run tests"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/models_test.exs`

Expected: Compilation error — `Greenlight.GitHub.Models` not found.

**Step 3: Implement the models**

Create `lib/greenlight/github/models.ex`:

```elixir
defmodule Greenlight.GitHub.Models do
  @moduledoc """
  Data structures for GitHub Actions API responses.
  """

  defmodule Step do
    @moduledoc false
    defstruct [:name, :status, :conclusion, :number, :started_at, :completed_at]

    def from_api(data) do
      %__MODULE__{
        name: data["name"],
        status: parse_status(data["status"]),
        conclusion: parse_conclusion(data["conclusion"]),
        number: data["number"],
        started_at: parse_datetime(data["started_at"]),
        completed_at: parse_datetime(data["completed_at"])
      }
    end

    defp parse_status(nil), do: nil
    defp parse_status("queued"), do: :queued
    defp parse_status("in_progress"), do: :in_progress
    defp parse_status("completed"), do: :completed
    defp parse_status(other), do: String.to_atom(other)

    defp parse_conclusion(nil), do: nil
    defp parse_conclusion("success"), do: :success
    defp parse_conclusion("failure"), do: :failure
    defp parse_conclusion("cancelled"), do: :cancelled
    defp parse_conclusion("skipped"), do: :skipped
    defp parse_conclusion(other), do: String.to_atom(other)

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end

  defmodule Job do
    @moduledoc false
    defstruct [:id, :name, :status, :conclusion, :started_at, :completed_at,
               :current_step, :html_url, steps: [], needs: []]

    def from_api(data) do
      steps = Enum.map(data["steps"] || [], &Step.from_api/1)

      current_step =
        steps
        |> Enum.find(&(&1.status == :in_progress))
        |> case do
          nil -> nil
          step -> step.name
        end

      %__MODULE__{
        id: data["id"],
        name: data["name"],
        status: Step.from_api(%{"status" => data["status"]}).status,
        conclusion: Step.from_api(%{"conclusion" => data["conclusion"]}).conclusion,
        started_at: parse_datetime(data["started_at"]),
        completed_at: parse_datetime(data["completed_at"]),
        html_url: data["html_url"],
        current_step: current_step,
        steps: steps
      }
    end

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end

  defmodule WorkflowRun do
    @moduledoc false
    defstruct [:id, :name, :workflow_id, :status, :conclusion, :head_sha,
               :event, :html_url, :created_at, :updated_at, jobs: []]

    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        workflow_id: data["workflow_id"],
        status: Step.from_api(%{"status" => data["status"]}).status,
        conclusion: Step.from_api(%{"conclusion" => data["conclusion"]}).conclusion,
        head_sha: data["head_sha"],
        event: data["event"],
        html_url: data["html_url"],
        created_at: parse_datetime(data["created_at"]),
        updated_at: parse_datetime(data["updated_at"])
      }
    end

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end
end
```

**Step 4: Run tests**

Run: `mix test test/greenlight/github/models_test.exs`

Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/greenlight/github/models.ex test/greenlight/github/models_test.exs
git commit -m "feat: add GitHub Actions data model structs with API parsing"
```

---

## Task 4: GitHub API Client

**Files:**
- Create: `lib/greenlight/github/client.ex`
- Create: `test/greenlight/github/client_test.exs`

**Step 1: Write tests for the client**

Create `test/greenlight/github/client_test.exs`. These tests use `Req.Test` to mock HTTP responses:

```elixir
defmodule Greenlight.GitHub.ClientTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Client

  setup do
    # Use Req.Test to stub HTTP calls
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      case conn.request_path do
        "/repos/owner/repo/actions/runs" ->
          Req.Test.json(conn, %{
            "workflow_runs" => [
              %{
                "id" => 1,
                "name" => "CI",
                "workflow_id" => 10,
                "status" => "completed",
                "conclusion" => "success",
                "head_sha" => "abc123",
                "event" => "push",
                "html_url" => "https://github.com/owner/repo/actions/runs/1",
                "created_at" => "2026-02-12T10:00:00Z",
                "updated_at" => "2026-02-12T10:05:00Z"
              }
            ]
          })

        "/repos/owner/repo/actions/runs/1/jobs" ->
          Req.Test.json(conn, %{
            "jobs" => [
              %{
                "id" => 100,
                "name" => "build",
                "status" => "completed",
                "conclusion" => "success",
                "started_at" => "2026-02-12T10:00:00Z",
                "completed_at" => "2026-02-12T10:02:00Z",
                "html_url" => "https://github.com/owner/repo/actions/runs/1/job/100",
                "steps" => []
              }
            ]
          })

        "/orgs/my-org/repos" ->
          Req.Test.json(conn, [
            %{"full_name" => "my-org/repo1"},
            %{"full_name" => "my-org/repo2"}
          ])

        "/repos/owner/repo/pulls" ->
          Req.Test.json(conn, [
            %{"number" => 42, "title" => "Add feature", "head" => %{"sha" => "pr-sha"}}
          ])

        "/repos/owner/repo/branches" ->
          Req.Test.json(conn, [
            %{"name" => "main", "commit" => %{"sha" => "branch-sha"}}
          ])

        "/repos/owner/repo/releases" ->
          Req.Test.json(conn, [
            %{"tag_name" => "v1.0.0", "name" => "Release 1.0"}
          ])
      end
    end)

    :ok
  end

  test "list_workflow_runs/3 returns parsed workflow runs" do
    {:ok, runs} = Client.list_workflow_runs("owner", "repo", head_sha: "abc123")
    assert [%Greenlight.GitHub.Models.WorkflowRun{id: 1, name: "CI"}] = runs
  end

  test "list_jobs/3 returns parsed jobs for a run" do
    {:ok, jobs} = Client.list_jobs("owner", "repo", 1)
    assert [%Greenlight.GitHub.Models.Job{id: 100, name: "build"}] = jobs
  end

  test "list_org_repos/1 returns repo full names" do
    {:ok, repos} = Client.list_org_repos("my-org")
    assert repos == ["my-org/repo1", "my-org/repo2"]
  end

  test "list_pulls/2 returns parsed pull requests" do
    {:ok, pulls} = Client.list_pulls("owner", "repo")
    assert [%{number: 42, title: "Add feature"}] = pulls
  end

  test "list_branches/2 returns parsed branches" do
    {:ok, branches} = Client.list_branches("owner", "repo")
    assert [%{name: "main"}] = branches
  end

  test "list_releases/2 returns parsed releases" do
    {:ok, releases} = Client.list_releases("owner", "repo")
    assert [%{tag_name: "v1.0.0"}] = releases
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/client_test.exs`

Expected: Compilation error — `Greenlight.GitHub.Client` not found.

**Step 3: Implement the client**

Create `lib/greenlight/github/client.ex`:

```elixir
defmodule Greenlight.GitHub.Client do
  @moduledoc """
  HTTP client for the GitHub REST API, using Req.
  """

  alias Greenlight.GitHub.Models

  @base_url "https://api.github.com"

  defp new do
    Req.new(
      base_url: @base_url,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"authorization", "Bearer #{Greenlight.Config.github_token()}"},
        {"x-github-api-version", "2022-11-28"}
      ]
    )
    |> Req.Test.transport(__MODULE__)
  end

  def list_workflow_runs(owner, repo, opts \\ []) do
    params = Enum.into(opts, %{})

    case Req.get(new(), url: "/repos/#{owner}/#{repo}/actions/runs", params: params) do
      {:ok, %{status: 200, body: body}} ->
        runs = Enum.map(body["workflow_runs"], &Models.WorkflowRun.from_api/1)
        {:ok, runs}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_jobs(owner, repo, run_id) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs") do
      {:ok, %{status: 200, body: body}} ->
        jobs = Enum.map(body["jobs"], &Models.Job.from_api/1)
        {:ok, jobs}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_org_repos(org) do
    case Req.get(new(), url: "/orgs/#{org}/repos", params: %{per_page: 100, sort: "pushed"}) do
      {:ok, %{status: 200, body: body}} ->
        repos = Enum.map(body, & &1["full_name"])
        {:ok, repos}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_pulls(owner, repo) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/pulls", params: %{state: "open", per_page: 30}) do
      {:ok, %{status: 200, body: body}} ->
        pulls = Enum.map(body, fn pr ->
          %{number: pr["number"], title: pr["title"], head_sha: pr["head"]["sha"]}
        end)
        {:ok, pulls}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_branches(owner, repo) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/branches", params: %{per_page: 30}) do
      {:ok, %{status: 200, body: body}} ->
        branches = Enum.map(body, fn b ->
          %{name: b["name"], sha: b["commit"]["sha"]}
        end)
        {:ok, branches}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_releases(owner, repo) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/releases", params: %{per_page: 30}) do
      {:ok, %{status: 200, body: body}} ->
        releases = Enum.map(body, fn r ->
          %{tag_name: r["tag_name"], name: r["name"]}
        end)
        {:ok, releases}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 4: Run tests**

Run: `mix test test/greenlight/github/client_test.exs`

Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/greenlight/github/client.ex test/greenlight/github/client_test.exs
git commit -m "feat: add GitHub API client with Req for workflow runs, jobs, repos, PRs, branches, releases"
```

---

## Task 5: Workflow Graph Builder

**Files:**
- Create: `lib/greenlight/github/workflow_graph.ex`
- Create: `test/greenlight/github/workflow_graph_test.exs`

**Step 1: Write test for graph building**

Create `test/greenlight/github/workflow_graph_test.exs`:

```elixir
defmodule Greenlight.GitHub.WorkflowGraphTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Models
  alias Greenlight.GitHub.WorkflowGraph

  describe "build_workflow_dag/1" do
    test "converts workflow runs to Svelte Flow nodes and edges" do
      runs = [
        %Models.WorkflowRun{
          id: 1, name: "CI", workflow_id: 10, status: :completed,
          conclusion: :success, head_sha: "abc", event: "push",
          html_url: "https://github.com/o/r/actions/runs/1",
          created_at: ~U[2026-02-12 10:00:00Z],
          updated_at: ~U[2026-02-12 10:05:00Z],
          jobs: [
            %Models.Job{id: 100, name: "build", status: :completed, conclusion: :success},
            %Models.Job{id: 101, name: "test", status: :completed, conclusion: :success}
          ]
        },
        %Models.WorkflowRun{
          id: 2, name: "Deploy", workflow_id: 20, status: :queued,
          conclusion: nil, head_sha: "abc", event: "workflow_run",
          html_url: "https://github.com/o/r/actions/runs/2",
          created_at: ~U[2026-02-12 10:05:00Z],
          updated_at: ~U[2026-02-12 10:05:00Z],
          jobs: []
        }
      ]

      %{nodes: nodes, edges: edges} = WorkflowGraph.build_workflow_dag(runs)

      assert length(nodes) == 2
      assert Enum.any?(nodes, fn n -> n.id == "wf-1" end)
      assert Enum.any?(nodes, fn n -> n.id == "wf-2" end)

      # workflow_run event creates an edge from CI -> Deploy
      assert length(edges) >= 1
      assert Enum.any?(edges, fn e -> e.source == "wf-1" and e.target == "wf-2" end)
    end
  end

  describe "build_job_dag/1" do
    test "converts jobs to Svelte Flow nodes and edges using needs" do
      jobs = [
        %Models.Job{
          id: 100, name: "build", status: :completed, conclusion: :success,
          html_url: "https://github.com/o/r/actions/runs/1/job/100",
          started_at: ~U[2026-02-12 10:00:00Z],
          completed_at: ~U[2026-02-12 10:02:00Z],
          current_step: nil, steps: [], needs: []
        },
        %Models.Job{
          id: 101, name: "test", status: :in_progress, conclusion: nil,
          html_url: "https://github.com/o/r/actions/runs/1/job/101",
          started_at: ~U[2026-02-12 10:02:00Z],
          completed_at: nil,
          current_step: "Run tests", steps: [
            %Models.Step{name: "Checkout", status: :completed, conclusion: :success, number: 1},
            %Models.Step{name: "Run tests", status: :in_progress, conclusion: nil, number: 2}
          ],
          needs: ["build"]
        },
        %Models.Job{
          id: 102, name: "deploy", status: :queued, conclusion: nil,
          html_url: "https://github.com/o/r/actions/runs/1/job/102",
          started_at: nil, completed_at: nil,
          current_step: nil, steps: [],
          needs: ["test"]
        }
      ]

      %{nodes: nodes, edges: edges} = WorkflowGraph.build_job_dag(jobs)

      assert length(nodes) == 3
      assert length(edges) == 2

      test_node = Enum.find(nodes, fn n -> n.id == "job-101" end)
      assert test_node.data.current_step == "Run tests"
      assert test_node.data.steps_completed == 1
      assert test_node.data.steps_total == 2
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/workflow_graph_test.exs`

Expected: Compilation error.

**Step 3: Implement the graph builder**

Create `lib/greenlight/github/workflow_graph.ex`:

```elixir
defmodule Greenlight.GitHub.WorkflowGraph do
  @moduledoc """
  Transforms GitHub Actions data into Svelte Flow node/edge format.
  """

  alias Greenlight.GitHub.Models

  def build_workflow_dag(workflow_runs) do
    nodes = Enum.map(workflow_runs, &workflow_to_node/1)

    # Build edges: workflow_run-triggered workflows depend on earlier workflows
    # with the same SHA
    non_workflow_run = Enum.reject(workflow_runs, &(&1.event == "workflow_run"))
    workflow_run_triggered = Enum.filter(workflow_runs, &(&1.event == "workflow_run"))

    edges =
      for target <- workflow_run_triggered,
          source <- non_workflow_run,
          source.head_sha == target.head_sha do
        %{
          id: "e-#{source.id}-#{target.id}",
          source: "wf-#{source.id}",
          target: "wf-#{target.id}",
          animated: target.status == :in_progress
        }
      end

    %{nodes: nodes, edges: edges}
  end

  def build_job_dag(jobs) do
    # Build a name -> id lookup for resolving `needs`
    name_to_id = Map.new(jobs, fn job -> {job.name, "job-#{job.id}"} end)

    nodes = Enum.map(jobs, &job_to_node/1)

    edges =
      for job <- jobs,
          needed_name <- job.needs || [],
          source_id = Map.get(name_to_id, needed_name),
          source_id != nil do
        %{
          id: "e-#{source_id}-job-#{job.id}",
          source: source_id,
          target: "job-#{job.id}",
          animated: job.status == :in_progress
        }
      end

    %{nodes: nodes, edges: edges}
  end

  defp workflow_to_node(%Models.WorkflowRun{} = run) do
    jobs_passed = Enum.count(run.jobs, &(&1.conclusion == :success))
    jobs_total = length(run.jobs)

    elapsed =
      if run.updated_at && run.created_at do
        DateTime.diff(run.updated_at, run.created_at, :second)
      else
        0
      end

    %{
      id: "wf-#{run.id}",
      type: "workflow",
      position: %{x: 0, y: 0},
      data: %{
        name: run.name,
        status: to_string(run.status),
        conclusion: run.conclusion && to_string(run.conclusion),
        elapsed: elapsed,
        jobs_passed: jobs_passed,
        jobs_total: jobs_total,
        html_url: run.html_url
      }
    }
  end

  defp job_to_node(%Models.Job{} = job) do
    steps_completed = Enum.count(job.steps, &(&1.status == :completed))
    steps_total = length(job.steps)

    elapsed =
      if job.started_at do
        end_time = job.completed_at || DateTime.utc_now()
        DateTime.diff(end_time, job.started_at, :second)
      else
        0
      end

    %{
      id: "job-#{job.id}",
      type: "job",
      position: %{x: 0, y: 0},
      data: %{
        name: job.name,
        status: to_string(job.status),
        conclusion: job.conclusion && to_string(job.conclusion),
        elapsed: elapsed,
        current_step: job.current_step,
        steps_completed: steps_completed,
        steps_total: steps_total,
        html_url: job.html_url
      }
    }
  end
end
```

**Step 4: Run tests**

Run: `mix test test/greenlight/github/workflow_graph_test.exs`

Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/greenlight/github/workflow_graph.ex test/greenlight/github/workflow_graph_test.exs
git commit -m "feat: add workflow graph builder to transform API data into Svelte Flow nodes/edges"
```

---

## Task 6: Poller GenServer and Public API

**Files:**
- Create: `lib/greenlight/github/poller.ex`
- Create: `lib/greenlight/pollers.ex`
- Create: `test/greenlight/github/poller_test.exs`

**Step 1: Write test for the poller**

Create `test/greenlight/github/poller_test.exs`:

```elixir
defmodule Greenlight.GitHub.PollerTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Poller
  alias Greenlight.Pollers

  setup do
    # Stub GitHub API responses
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      case conn.request_path do
        "/repos/owner/repo/actions/runs" ->
          Req.Test.json(conn, %{
            "workflow_runs" => [
              %{
                "id" => 1, "name" => "CI", "workflow_id" => 10,
                "status" => "completed", "conclusion" => "success",
                "head_sha" => "abc123", "event" => "push",
                "html_url" => "https://github.com/owner/repo/actions/runs/1",
                "created_at" => "2026-02-12T10:00:00Z",
                "updated_at" => "2026-02-12T10:05:00Z"
              }
            ]
          })

        "/repos/owner/repo/actions/runs/1/jobs" ->
          Req.Test.json(conn, %{
            "jobs" => [
              %{
                "id" => 100, "name" => "build",
                "status" => "completed", "conclusion" => "success",
                "started_at" => "2026-02-12T10:00:00Z",
                "completed_at" => "2026-02-12T10:02:00Z",
                "html_url" => "https://github.com/owner/repo/actions/runs/1/job/100",
                "steps" => []
              }
            ]
          })
      end
    end)

    :ok
  end

  test "poller fetches data and broadcasts via PubSub" do
    Phoenix.PubSub.subscribe(Greenlight.PubSub, "pipeline:owner/repo:abc123")

    {:ok, pid} =
      start_supervised(
        {Poller, owner: "owner", repo: "repo", ref: "abc123", poll_interval: 100}
      )

    # Should receive a broadcast with pipeline data
    assert_receive {:pipeline_update, %{nodes: nodes, edges: _edges}}, 5_000
    assert length(nodes) > 0

    stop_supervised(Poller)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/poller_test.exs`

Expected: Compilation error.

**Step 3: Implement the poller**

Create `lib/greenlight/github/poller.ex`:

```elixir
defmodule Greenlight.GitHub.Poller do
  @moduledoc """
  GenServer that polls GitHub Actions API for workflow runs
  and broadcasts updates via PubSub.
  """

  use GenServer

  alias Greenlight.GitHub.{Client, WorkflowGraph}

  @active_interval 10_000
  @idle_interval 60_000

  defstruct [:owner, :repo, :ref, :poll_interval, :last_state, monitors: %{}, subscriber_count: 0]

  def start_link(opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)
    ref = Keyword.fetch!(opts, :ref)
    name = {:via, Registry, {Greenlight.PollerRegistry, {owner, repo, ref}}}

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def subscribe(pid) do
    GenServer.call(pid, {:subscribe, self()})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      owner: Keyword.fetch!(opts, :owner),
      repo: Keyword.fetch!(opts, :repo),
      ref: Keyword.fetch!(opts, :ref),
      poll_interval: Keyword.get(opts, :poll_interval, @active_interval)
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    mon_ref = Process.monitor(pid)

    state = %{state |
      monitors: Map.put(state.monitors, mon_ref, pid),
      subscriber_count: state.subscriber_count + 1
    }

    reply = state.last_state
    {:reply, {:ok, reply}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = do_poll(state)
    schedule_poll(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, mon_ref, :process, _pid, _reason}, state) do
    state = %{state |
      monitors: Map.delete(state.monitors, mon_ref),
      subscriber_count: state.subscriber_count - 1
    }

    if state.subscriber_count <= 0 do
      # Grace period before shutdown
      Process.send_after(self(), :check_shutdown, 60_000)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_shutdown, state) do
    if state.subscriber_count <= 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  defp do_poll(state) do
    topic = "pipeline:#{state.owner}/#{state.repo}:#{state.ref}"

    with {:ok, runs} <- Client.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
         runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do
      graph_data = WorkflowGraph.build_workflow_dag(runs_with_jobs)

      if graph_data != state.last_state do
        Phoenix.PubSub.broadcast(
          Greenlight.PubSub,
          topic,
          {:pipeline_update, graph_data}
        )
      end

      %{state | last_state: graph_data, poll_interval: compute_interval(runs_with_jobs)}
    else
      {:error, _reason} ->
        state
    end
  end

  defp fetch_jobs_for_runs(owner, repo, runs) do
    Enum.map(runs, fn run ->
      case Client.list_jobs(owner, repo, run.id) do
        {:ok, jobs} -> %{run | jobs: jobs}
        {:error, _} -> run
      end
    end)
  end

  defp compute_interval(runs) do
    any_active? = Enum.any?(runs, &(&1.status == :in_progress))
    if any_active?, do: @active_interval, else: @idle_interval
  end

  defp schedule_poll(state) do
    Process.send_after(self(), :poll, state.poll_interval)
  end
end
```

**Step 4: Create the public API module**

Create `lib/greenlight/pollers.ex`:

```elixir
defmodule Greenlight.Pollers do
  @moduledoc """
  Public API for subscribing to pipeline pollers.
  """

  alias Greenlight.GitHub.Poller

  def subscribe(owner, repo, ref) do
    # Subscribe to PubSub topic
    topic = "pipeline:#{owner}/#{repo}:#{ref}"
    Phoenix.PubSub.subscribe(Greenlight.PubSub, topic)

    # Find or start the poller
    case Registry.lookup(Greenlight.PollerRegistry, {owner, repo, ref}) do
      [{pid, _}] ->
        Poller.subscribe(pid)

      [] ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Greenlight.PollerSupervisor,
            {Poller, owner: owner, repo: repo, ref: ref}
          )

        Poller.subscribe(pid)
    end
  end
end
```

**Step 5: Add Registry to application.ex**

Add the registry to the children list in `lib/greenlight/application.ex`, before the DynamicSupervisor:

```elixir
{Registry, keys: :unique, name: Greenlight.PollerRegistry},
```

**Step 6: Run tests**

Run: `mix test test/greenlight/github/poller_test.exs`

Expected: All tests pass.

**Step 7: Commit**

```bash
git add lib/greenlight/github/poller.ex lib/greenlight/pollers.ex lib/greenlight/application.ex test/greenlight/github/poller_test.exs
git commit -m "feat: add poller GenServer with PubSub broadcasting and DynamicSupervisor lifecycle"
```

---

## Task 7: Svelte Components — DagViewer, WorkflowNode, JobNode

**Files:**
- Create: `assets/svelte/DagViewer.svelte`
- Create: `assets/svelte/nodes/WorkflowNode.svelte`
- Create: `assets/svelte/nodes/JobNode.svelte`
- Create: `assets/svelte/components/StatusBadge.svelte`
- Create: `assets/svelte/components/ProgressBar.svelte`

**Step 1: Create StatusBadge component**

Create `assets/svelte/components/StatusBadge.svelte`:

```svelte
<script>
  export let status = "queued"
  export let conclusion = null

  $: displayStatus = conclusion || status
  $: colorClass = {
    queued: "bg-gray-400",
    in_progress: "bg-amber-400 animate-pulse",
    success: "bg-green-500",
    failure: "bg-red-500",
    cancelled: "bg-gray-400",
    skipped: "bg-gray-300"
  }[displayStatus] || "bg-gray-400"
</script>

<span class="inline-flex items-center gap-1.5">
  <span class="w-2.5 h-2.5 rounded-full {colorClass}"></span>
  <span class="text-xs font-medium capitalize {conclusion === 'cancelled' ? 'line-through' : ''}">
    {displayStatus}
  </span>
</span>
```

**Step 2: Create ProgressBar component**

Create `assets/svelte/components/ProgressBar.svelte`:

```svelte
<script>
  export let completed = 0
  export let total = 0

  $: percent = total > 0 ? Math.round((completed / total) * 100) : 0
</script>

<div class="w-full bg-gray-200 rounded-full h-1.5 dark:bg-gray-700">
  <div
    class="h-1.5 rounded-full transition-all duration-500 {percent === 100 ? 'bg-green-500' : 'bg-amber-400'}"
    style="width: {percent}%"
  ></div>
</div>
```

**Step 3: Create WorkflowNode component**

Create `assets/svelte/nodes/WorkflowNode.svelte`:

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';

  export let data;

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }
</script>

<Handle type="target" position={Position.Top} />

<div class="px-4 py-3 rounded-lg border-2 bg-white dark:bg-gray-800 shadow-md min-w-[200px]
  {data.conclusion === 'failure' ? 'border-red-400' : data.status === 'in_progress' ? 'border-amber-400' : data.conclusion === 'success' ? 'border-green-400' : 'border-gray-300'}">
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-semibold text-sm truncate">{data.name}</span>
    <button on:click={openGitHub} class="text-gray-400 hover:text-blue-500 transition-colors" title="View on GitHub">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-3">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-gray-500">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.jobs_total > 0}
    <div class="text-xs text-gray-500 mt-1">{data.jobs_passed}/{data.jobs_total} jobs passed</div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
```

**Step 4: Create JobNode component**

Create `assets/svelte/nodes/JobNode.svelte`:

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';
  import ProgressBar from '../components/ProgressBar.svelte';

  export let data;

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }
</script>

<Handle type="target" position={Position.Top} />

<div class="px-3 py-2 rounded-lg border bg-white dark:bg-gray-800 shadow-sm min-w-[180px]
  {data.conclusion === 'failure' ? 'border-red-300' : data.status === 'in_progress' ? 'border-amber-300' : data.conclusion === 'success' ? 'border-green-300' : 'border-gray-200'}">
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-medium text-xs truncate">{data.name}</span>
    <button on:click={openGitHub} class="text-gray-400 hover:text-blue-500 transition-colors" title="View on GitHub">
      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-2">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-gray-500">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.current_step}
    <div class="text-xs text-amber-600 dark:text-amber-400 mt-1 truncate" title={data.current_step}>
      ▸ {data.current_step}
    </div>
  {/if}
  {#if data.steps_total > 0}
    <div class="mt-1.5">
      <ProgressBar completed={data.steps_completed} total={data.steps_total} />
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
```

**Step 5: Create DagViewer component**

Create `assets/svelte/DagViewer.svelte`:

```svelte
<script>
  import { SvelteFlow, Background, Controls, MiniMap } from '@xyflow/svelte';
  import dagre from 'dagre';
  import WorkflowNode from './nodes/WorkflowNode.svelte';
  import JobNode from './nodes/JobNode.svelte';
  import '@xyflow/svelte/dist/style.css';

  export let nodes = [];
  export let edges = [];
  export let view_level = "workflows";
  export let live;

  const nodeTypes = {
    workflow: WorkflowNode,
    job: JobNode
  };

  function getLayoutedElements(inputNodes, inputEdges, direction = 'TB') {
    const g = new dagre.graphlib.Graph();
    g.setDefaultEdgeLabel(() => ({}));
    g.setGraph({ rankdir: direction, nodesep: 50, ranksep: 80 });

    const nodeWidth = view_level === 'workflows' ? 220 : 200;
    const nodeHeight = view_level === 'workflows' ? 100 : 90;

    inputNodes.forEach(node => {
      g.setNode(node.id, { width: nodeWidth, height: nodeHeight });
    });

    inputEdges.forEach(edge => {
      g.setEdge(edge.source, edge.target);
    });

    dagre.layout(g);

    return inputNodes.map(node => {
      const pos = g.node(node.id);
      return {
        ...node,
        position: {
          x: pos.x - nodeWidth / 2,
          y: pos.y - nodeHeight / 2
        }
      };
    });
  }

  $: layoutedNodes = getLayoutedElements(nodes, edges);

  function handleNodeClick(event) {
    const node = event.detail.node;
    if (view_level === 'workflows' && node.type === 'workflow') {
      live.pushEvent("node_clicked", { workflow_run_id: parseInt(node.id.replace("wf-", "")) });
    }
  }

  function handleBackClick() {
    live.pushEvent("back_clicked", {});
  }
</script>

<div class="w-full h-[600px] relative">
  {#if view_level === 'jobs'}
    <button
      on:click={handleBackClick}
      class="absolute top-3 left-3 z-10 px-3 py-1.5 text-sm bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors flex items-center gap-1.5"
    >
      ← Back to workflows
    </button>
  {/if}

  <SvelteFlow
    nodes={layoutedNodes}
    {edges}
    {nodeTypes}
    fitView
    on:nodeclick={handleNodeClick}
    nodesDraggable={false}
    nodesConnectable={false}
    elementsSelectable={true}
    defaultEdgeOptions={{ type: 'smoothstep' }}
  >
    <Background />
    <Controls />
    <MiniMap />
  </SvelteFlow>
</div>
```

**Step 6: Verify the build compiles**

Run: `mix assets.build`

Expected: No errors. The Svelte components compile via the LiveSvelte build process.

**Step 7: Commit**

```bash
git add assets/svelte/
git commit -m "feat: add Svelte Flow DAG viewer with custom workflow and job node components"
```

---

## Task 8: Pipeline LiveView (DAG View Page)

**Files:**
- Create: `lib/greenlight_web/live/pipeline_live.ex`
- Modify: `lib/greenlight_web/router.ex`

**Step 1: Implement PipelineLive**

Create `lib/greenlight_web/live/pipeline_live.ex`:

```elixir
defmodule GreenlightWeb.PipelineLive do
  use GreenlightWeb, :live_view

  alias Greenlight.Pollers
  alias Greenlight.GitHub.{Client, WorkflowGraph}

  @impl true
  def mount(%{"owner" => owner, "repo" => repo, "sha" => sha}, _session, socket) do
    socket =
      socket
      |> assign(
        owner: owner,
        repo: repo,
        sha: sha,
        view_level: "workflows",
        selected_run_id: nil,
        nodes: [],
        edges: [],
        page_title: "#{owner}/#{repo} - #{String.slice(sha, 0, 7)}"
      )

    if connected?(socket) do
      {:ok, state} = Pollers.subscribe(owner, repo, sha)

      socket =
        if state do
          assign(socket, nodes: state.nodes, edges: state.edges)
        else
          socket
        end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({:pipeline_update, %{nodes: nodes, edges: edges}}, socket) do
    socket =
      case socket.assigns.view_level do
        "workflows" ->
          assign(socket, nodes: nodes, edges: edges)

        "jobs" ->
          # Re-fetch job data for the selected run
          refresh_job_view(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("node_clicked", %{"workflow_run_id" => run_id}, socket) do
    case Client.list_jobs(socket.assigns.owner, socket.assigns.repo, run_id) do
      {:ok, jobs} ->
        %{nodes: nodes, edges: edges} = WorkflowGraph.build_job_dag(jobs)

        {:noreply,
         assign(socket,
           view_level: "jobs",
           selected_run_id: run_id,
           nodes: nodes,
           edges: edges
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load jobs")}
    end
  end

  @impl true
  def handle_event("back_clicked", _params, socket) do
    # Re-subscribe to get the latest workflow-level data
    {:ok, state} =
      Pollers.subscribe(socket.assigns.owner, socket.assigns.repo, socket.assigns.sha)

    socket =
      if state do
        assign(socket,
          view_level: "workflows",
          selected_run_id: nil,
          nodes: state.nodes,
          edges: state.edges
        )
      else
        assign(socket, view_level: "workflows", selected_run_id: nil, nodes: [], edges: [])
      end

    {:noreply, socket}
  end

  defp refresh_job_view(socket) do
    case socket.assigns.selected_run_id do
      nil ->
        socket

      run_id ->
        case Client.list_jobs(socket.assigns.owner, socket.assigns.repo, run_id) do
          {:ok, jobs} ->
            %{nodes: nodes, edges: edges} = WorkflowGraph.build_job_dag(jobs)
            assign(socket, nodes: nodes, edges: edges)

          {:error, _} ->
            socket
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-6xl mx-auto">
        <div class="mb-6">
          <div class="flex items-center gap-2 text-sm text-gray-500 mb-1">
            <.link navigate={~p"/repos/#{@owner}/#{@repo}"} class="hover:text-blue-600 transition-colors">
              {@owner}/{@repo}
            </.link>
            <span>/</span>
            <span class="font-mono">{String.slice(@sha, 0, 7)}</span>
          </div>
          <h1 class="text-2xl font-bold">
            Pipeline
            <span class="text-base font-normal text-gray-500">
              ({@view_level})
            </span>
          </h1>
        </div>

        <.svelte
          name="DagViewer"
          props={%{
            nodes: @nodes,
            edges: @edges,
            view_level: @view_level
          }}
          socket={@socket}
        />
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 2: Add routes to router.ex**

Replace the existing browser scope in `lib/greenlight_web/router.ex`:

```elixir
scope "/", GreenlightWeb do
  pipe_through :browser

  get "/", PageController, :home

  live "/repos/:owner/:repo/commit/:sha", PipelineLive
end
```

**Step 3: Verify it compiles**

Run: `mix compile`

Expected: No errors.

**Step 4: Commit**

```bash
git add lib/greenlight_web/live/pipeline_live.ex lib/greenlight_web/router.ex
git commit -m "feat: add PipelineLive with DAG view, drill-down, and poller subscription"
```

---

## Task 9: Dashboard LiveView

**Files:**
- Create: `lib/greenlight_web/live/dashboard_live.ex`
- Modify: `lib/greenlight_web/router.ex`

**Step 1: Implement DashboardLive**

Create `lib/greenlight_web/live/dashboard_live.ex`:

```elixir
defmodule GreenlightWeb.DashboardLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client

  @impl true
  def mount(_params, _session, socket) do
    bookmarked = Greenlight.Config.bookmarked_repos()
    orgs = Greenlight.Config.followed_orgs()

    socket =
      assign(socket,
        page_title: "Dashboard",
        bookmarked_repos: bookmarked,
        followed_orgs: orgs,
        org_repos: %{},
        expanded_orgs: MapSet.new()
      )

    if connected?(socket) do
      send(self(), :load_org_repos)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_org_repos, socket) do
    org_repos =
      socket.assigns.followed_orgs
      |> Enum.reduce(%{}, fn org, acc ->
        case Client.list_org_repos(org) do
          {:ok, repos} -> Map.put(acc, org, repos)
          {:error, _} -> Map.put(acc, org, [])
        end
      end)

    {:noreply, assign(socket, org_repos: org_repos)}
  end

  @impl true
  def handle_event("toggle_org", %{"org" => org}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_orgs, org) do
        MapSet.delete(socket.assigns.expanded_orgs, org)
      else
        MapSet.put(socket.assigns.expanded_orgs, org)
      end

    {:noreply, assign(socket, expanded_orgs: expanded)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold mb-8">Greenlight</h1>

        <section :if={@bookmarked_repos != []} class="mb-10">
          <h2 class="text-lg font-semibold mb-4">Bookmarked Repos</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.link
              :for={repo <- @bookmarked_repos}
              navigate={~p"/repos/#{repo}"}
              class="block p-4 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 dark:hover:border-blue-500 transition-colors"
            >
              <span class="font-medium">{repo}</span>
            </.link>
          </div>
        </section>

        <section :if={@followed_orgs != []} class="mb-10">
          <h2 class="text-lg font-semibold mb-4">Organizations</h2>
          <div :for={org <- @followed_orgs} class="mb-4">
            <button
              phx-click="toggle_org"
              phx-value-org={org}
              class="flex items-center gap-2 w-full text-left p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <span class="text-xs">{if MapSet.member?(@expanded_orgs, org), do: "▼", else: "▶"}</span>
              <span class="font-medium">{org}</span>
              <span class="text-sm text-gray-500 ml-auto">
                {length(Map.get(@org_repos, org, []))} repos
              </span>
            </button>

            <div :if={MapSet.member?(@expanded_orgs, org)} class="mt-2 ml-6 space-y-1">
              <.link
                :for={repo <- Map.get(@org_repos, org, [])}
                navigate={~p"/repos/#{repo}"}
                class="block p-2 rounded text-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                {repo}
              </.link>
            </div>
          </div>
        </section>

        <div :if={@bookmarked_repos == [] and @followed_orgs == []} class="text-center py-16 text-gray-500">
          <p class="text-lg mb-2">No repos configured yet</p>
          <p class="text-sm">
            Set <code class="bg-gray-100 dark:bg-gray-800 px-1 rounded">GREENLIGHT_BOOKMARKED_REPOS</code>
            and <code class="bg-gray-100 dark:bg-gray-800 px-1 rounded">GREENLIGHT_FOLLOWED_ORGS</code>
            environment variables
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 2: Update router**

Add dashboard routes to `lib/greenlight_web/router.ex`:

```elixir
scope "/", GreenlightWeb do
  pipe_through :browser

  get "/", PageController, :home
  live "/dashboard", DashboardLive
  live "/repos/:owner/:repo/commit/:sha", PipelineLive
end
```

**Step 3: Verify it compiles and renders**

Run: `mix phx.server`

Visit `http://localhost:4000/dashboard`. Expected: empty state message about env vars.

**Step 4: Commit**

```bash
git add lib/greenlight_web/live/dashboard_live.ex lib/greenlight_web/router.ex
git commit -m "feat: add dashboard LiveView with bookmarked repos and org browsing"
```

---

## Task 10: Repo LiveView (Ref Selector with Tabs)

**Files:**
- Create: `lib/greenlight_web/live/repo_live.ex`
- Modify: `lib/greenlight_web/router.ex`

**Step 1: Implement RepoLive**

Create `lib/greenlight_web/live/repo_live.ex`:

```elixir
defmodule GreenlightWeb.RepoLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client

  @impl true
  def mount(%{"owner" => owner, "repo" => repo}, _session, socket) do
    socket =
      assign(socket,
        owner: owner,
        repo: repo,
        active_tab: "commits",
        page_title: "#{owner}/#{repo}",
        commits: [],
        pulls: [],
        branches: [],
        releases: [],
        loading: true
      )

    if connected?(socket) do
      send(self(), :load_data)
    end

    {:ok, socket}
  end

  # Handle the case where owner/repo is passed as a single path segment like "org/repo"
  def mount(%{"path" => path_parts}, session, socket) when is_list(path_parts) do
    case path_parts do
      [owner, repo] -> mount(%{"owner" => owner, "repo" => repo}, session, socket)
      _ -> {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_info(:load_data, socket) do
    %{owner: owner, repo: repo} = socket.assigns

    pulls = case Client.list_pulls(owner, repo) do
      {:ok, data} -> data
      {:error, _} -> []
    end

    branches = case Client.list_branches(owner, repo) do
      {:ok, data} -> data
      {:error, _} -> []
    end

    releases = case Client.list_releases(owner, repo) do
      {:ok, data} -> data
      {:error, _} -> []
    end

    # Fetch recent workflow runs for the "commits" tab
    commits = case Client.list_workflow_runs(owner, repo, per_page: 20) do
      {:ok, runs} ->
        runs
        |> Enum.uniq_by(& &1.head_sha)
        |> Enum.take(20)
      {:error, _} -> []
    end

    {:noreply,
     assign(socket,
       commits: commits,
       pulls: pulls,
       branches: branches,
       releases: releases,
       loading: false
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/dashboard"} class="text-sm text-gray-500 hover:text-blue-600 transition-colors">
            ← Dashboard
          </.link>
          <h1 class="text-2xl font-bold mt-2">{@owner}/{@repo}</h1>
        </div>

        <div class="flex border-b border-gray-200 dark:border-gray-700 mb-6">
          <button
            :for={tab <- ["pulls", "branches", "releases", "commits"]}
            phx-click="switch_tab"
            phx-value-tab={tab}
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors capitalize",
              if(@active_tab == tab,
                do: "border-blue-500 text-blue-600",
                else: "border-transparent text-gray-500 hover:text-gray-700"
              )
            ]}
          >
            {tab}
          </button>
        </div>

        <div :if={@loading} class="text-center py-8 text-gray-500">Loading...</div>

        <div :if={!@loading}>
          <div :if={@active_tab == "commits"} class="space-y-2">
            <.link
              :for={run <- @commits}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{run.head_sha}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center justify-between">
                <span class="font-mono text-sm">{String.slice(run.head_sha, 0, 7)}</span>
                <span class={[
                  "text-xs px-2 py-0.5 rounded-full",
                  status_badge_class(run.status, run.conclusion)
                ]}>
                  {run.conclusion || run.status}
                </span>
              </div>
              <div class="text-sm text-gray-500 mt-1">{run.name} · {run.event}</div>
            </.link>
            <div :if={@commits == []} class="text-center py-8 text-gray-500">No recent workflow runs</div>
          </div>

          <div :if={@active_tab == "pulls"} class="space-y-2">
            <.link
              :for={pr <- @pulls}
              navigate={~p"/repos/#{@owner}/#{@repo}/pull/#{pr.number}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center gap-2">
                <span class="text-gray-500">#{pr.number}</span>
                <span class="font-medium text-sm">{pr.title}</span>
              </div>
            </.link>
            <div :if={@pulls == []} class="text-center py-8 text-gray-500">No open pull requests</div>
          </div>

          <div :if={@active_tab == "branches"} class="space-y-2">
            <.link
              :for={branch <- @branches}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{branch.sha}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <span class="font-medium text-sm">{branch.name}</span>
            </.link>
            <div :if={@branches == []} class="text-center py-8 text-gray-500">No branches</div>
          </div>

          <div :if={@active_tab == "releases"} class="space-y-2">
            <.link
              :for={release <- @releases}
              navigate={~p"/repos/#{@owner}/#{@repo}/release/#{release.tag_name}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center gap-2">
                <span class="font-mono text-sm">{release.tag_name}</span>
                <span :if={release.name} class="text-sm text-gray-500">{release.name}</span>
              </div>
            </.link>
            <div :if={@releases == []} class="text-center py-8 text-gray-500">No releases</div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
      s when s in [:failure, "failure"] -> "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
      s when s in [:in_progress, "in_progress"] -> "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200"
      _ -> "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"
    end
  end
end
```

**Step 2: Add all remaining routes to router.ex**

Update the browser scope in `lib/greenlight_web/router.ex` to its final form:

```elixir
scope "/", GreenlightWeb do
  pipe_through :browser

  live "/", DashboardLive
  live "/dashboard", DashboardLive
  live "/repos/:owner/:repo", RepoLive
  live "/repos/:owner/:repo/commit/:sha", PipelineLive
  live "/repos/:owner/:repo/pull/:number", PipelineLive
  live "/repos/:owner/:repo/release/:tag", PipelineLive
end
```

Note: Remove the `get "/", PageController, :home` route since the dashboard replaces it.

**Step 3: Update PipelineLive to handle PR and release routes**

Add additional `mount` clauses to `lib/greenlight_web/live/pipeline_live.ex` for PR and release routes:

```elixir
# PR route - look up the head SHA from the PR number
def mount(%{"owner" => owner, "repo" => repo, "number" => number}, _session, socket) do
  case Client.list_pulls(owner, repo) do
    {:ok, pulls} ->
      pr = Enum.find(pulls, fn p -> p.number == String.to_integer(number) end)

      if pr do
        mount(%{"owner" => owner, "repo" => repo, "sha" => pr.head_sha}, _session, socket)
      else
        {:ok, socket |> put_flash(:error, "PR ##{number} not found") |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
      end

    {:error, _} ->
      {:ok, socket |> put_flash(:error, "Failed to load PR") |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
  end
end

# Release route - look up the tag SHA
def mount(%{"owner" => owner, "repo" => repo, "tag" => tag}, _session, socket) do
  case Client.list_workflow_runs(owner, repo, event: "release") do
    {:ok, runs} ->
      run = Enum.find(runs, fn r -> r.head_sha end)

      if run do
        mount(%{"owner" => owner, "repo" => repo, "sha" => run.head_sha}, _session, socket)
      else
        {:ok, socket |> put_flash(:error, "No runs found for release #{tag}") |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
      end

    {:error, _} ->
      {:ok, socket |> put_flash(:error, "Failed to load release") |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
  end
end
```

**Step 4: Verify it compiles**

Run: `mix compile`

Expected: No errors.

**Step 5: Commit**

```bash
git add lib/greenlight_web/live/repo_live.ex lib/greenlight_web/live/pipeline_live.ex lib/greenlight_web/router.ex
git commit -m "feat: add repo ref selector with tabs and complete routing"
```

---

## Task 11: Clean Up and Remove Smoke Test

**Files:**
- Delete: `lib/greenlight_web/live/test_live.ex`
- Delete: `assets/svelte/Hello.svelte`
- Modify: `lib/greenlight_web/router.ex` (remove test route if still present)
- Delete: `lib/greenlight_web/controllers/page_controller.ex`
- Delete: `lib/greenlight_web/controllers/page_html.ex`
- Delete: `lib/greenlight_web/controllers/page_html/` (templates directory)

**Step 1: Remove the test LiveView, Hello.svelte, and unused page controller**

Delete the files listed above.

**Step 2: Verify it compiles and all routes work**

Run: `mix compile && mix phx.routes`

Expected: Routes for DashboardLive, RepoLive, PipelineLive all present.

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove smoke test component and unused page controller"
```

---

## Task 12: End-to-End Manual Test

**Not a code task — manual verification.**

**Step 1: Set environment variables**

```bash
export GITHUB_TOKEN="your-github-pat"
export GREENLIGHT_BOOKMARKED_REPOS="owner/repo1,owner/repo2"
export GREENLIGHT_FOLLOWED_ORGS="your-org"
```

**Step 2: Start the server**

Run: `mix phx.server`

**Step 3: Test each page**

1. Visit `http://localhost:4000/` — Dashboard loads with bookmarked repos and org
2. Click a repo — navigates to ref selector with tabs
3. Click a commit SHA — navigates to DAG view
4. Verify workflow nodes appear with status colors
5. Click a workflow node — drill into job-level DAG
6. Click "Back to workflows" — returns to workflow view
7. Click the external link icon on a node — opens GitHub in new tab
8. Wait 10-30s — verify nodes update status automatically

**Step 4: Run the precommit suite**

Run: `mix precommit`

Expected: Compiles without warnings, formatting clean, tests pass.

**Step 5: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues found during end-to-end testing"
```

---

## Task Summary

| Task | What it builds | Key files |
|------|---------------|-----------|
| 1 | LiveSvelte + deps setup | mix.exs, config, app.js, app.css |
| 2 | Config module + supervision tree | config.ex, application.ex |
| 3 | Data model structs | models.ex |
| 4 | GitHub API client | client.ex |
| 5 | Workflow graph builder | workflow_graph.ex |
| 6 | Poller GenServer + public API | poller.ex, pollers.ex |
| 7 | Svelte components | DagViewer, WorkflowNode, JobNode |
| 8 | Pipeline LiveView (DAG page) | pipeline_live.ex |
| 9 | Dashboard LiveView | dashboard_live.ex |
| 10 | Repo LiveView (ref selector) | repo_live.ex |
| 11 | Cleanup | Remove smoke test, unused files |
| 12 | End-to-end manual test | Verification |
