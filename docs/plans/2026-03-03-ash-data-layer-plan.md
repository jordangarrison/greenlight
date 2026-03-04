# Ash Declarative Data Layer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace hand-rolled GitHub API structs and scattered Client calls with Ash declarative resources, giving every piece of data in the system a typed, attributted resource accessed through a single `Greenlight.GitHub` domain interface.

**Architecture:** Define 10 Ash resources (WorkflowRun, Job, Step, Repository, Pull, Branch, Release, User, UserPR, UserCommit) backed by ManualRead actions that call the existing HTTP client. A `Greenlight.GitHub` Ash Domain provides the code interface. GenServers remain as thin polling orchestrators that call through the domain. Client stays as the HTTP transport layer.

**Tech Stack:** Ash Framework ~> 3.19, Phoenix 1.8, Req HTTP client, no database

**Design doc:** `docs/plans/2026-03-03-ash-data-layer-design.md`

---

## Task 1: Add Ash Dependency and Configure

**Files:**
- Modify: `mix.exs:41-69` (deps function)
- Modify: `config/config.exs:10-12` (app config)

**Step 1: Add ash dependency to mix.exs**

In `mix.exs`, add `{:ash, "~> 3.19"}` to the deps list:

```elixir
# mix.exs:41-69 — add after line 68 ({:bandit, "~> 1.5"})
{:ash, "~> 3.19"}
```

**Step 2: Add Ash domain config**

In `config/config.exs`, update the greenlight config block at line 10:

```elixir
# config/config.exs:10-12 — replace with:
config :greenlight,
  generators: [timestamp_type: :utc_datetime],
  ssr_enabled: true,
  ash_domains: [Greenlight.GitHub]
```

**Step 3: Fetch deps and verify compilation**

Run: `mix deps.get && mix compile`
Expected: Dependencies fetched, compilation succeeds (the domain module doesn't exist yet so there may be a warning — that's fine, Ash is lenient about this until the domain is used)

**Step 4: Commit**

```
feat: add ash framework dependency
```

---

## Task 2: Create Ash Resources — Step (Embedded), Job, WorkflowRun

These are the core pipeline resources. Step is embedded (comes inside Job API response). Job and WorkflowRun are standalone resources.

**Files:**
- Create: `lib/greenlight/github/step.ex`
- Create: `lib/greenlight/github/job.ex`
- Create: `lib/greenlight/github/workflow_run.ex`

**Step 1: Create the Step embedded resource**

```elixir
# lib/greenlight/github/step.ex
defmodule Greenlight.GitHub.Step do
  @moduledoc """
  A single step within a GitHub Actions job.
  Embedded resource — always comes as part of a Job API response.
  """

  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :number, :integer, public?: true
    attribute :started_at, :utc_datetime, public?: true
    attribute :completed_at, :utc_datetime, public?: true
  end
end
```

**Step 2: Create the Job resource**

```elixir
# lib/greenlight/github/job.ex
defmodule Greenlight.GitHub.Job do
  @moduledoc """
  A job within a GitHub Actions workflow run.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :started_at, :utc_datetime, public?: true
    attribute :completed_at, :utc_datetime, public?: true
    attribute :current_step, :string, public?: true
    attribute :html_url, :string, public?: true
    attribute :needs, {:array, :string}, default: [], public?: true
    attribute :steps, {:array, Greenlight.GitHub.Step}, default: [], public?: true
    attribute :owner, :string, public?: true
    attribute :repo, :string, public?: true
    attribute :run_id, :integer, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :run_id, :integer, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListJobs
    end
  end
end
```

**Step 3: Create the WorkflowRun resource**

```elixir
# lib/greenlight/github/workflow_run.ex
defmodule Greenlight.GitHub.WorkflowRun do
  @moduledoc """
  A GitHub Actions workflow run.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :workflow_id, :integer, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :head_sha, :string, public?: true
    attribute :event, :string, public?: true
    attribute :html_url, :string, public?: true
    attribute :path, :string, public?: true
    attribute :created_at, :utc_datetime, public?: true
    attribute :updated_at, :utc_datetime, public?: true
    attribute :owner, :string, public?: true
    attribute :repo, :string, public?: true
    attribute :jobs, {:array, Greenlight.GitHub.Job}, default: [], public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :head_sha, :string
      argument :event, :string
      argument :per_page, :integer

      manual Greenlight.GitHub.Actions.ListWorkflowRuns
    end

    read :get do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :run_id, :integer, allow_nil?: false

      get? true

      manual Greenlight.GitHub.Actions.GetWorkflowRun
    end
  end
end
```

**Step 4: Verify compilation**

Run: `mix compile`
Expected: Compilation succeeds. Warnings about missing Domain and Action modules are expected at this stage.

**Step 5: Commit**

```
feat: add core Ash resources for WorkflowRun, Job, Step
```

---

## Task 3: Create Ash Resources — Repository, Pull, Branch, Release

**Files:**
- Create: `lib/greenlight/github/repository.ex`
- Create: `lib/greenlight/github/pull.ex`
- Create: `lib/greenlight/github/branch.ex`
- Create: `lib/greenlight/github/release.ex`

**Step 1: Create Repository resource**

```elixir
# lib/greenlight/github/repository.ex
defmodule Greenlight.GitHub.Repository do
  @moduledoc """
  A GitHub repository.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :full_name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :owner, :string, public?: true
  end

  actions do
    read :list_for_org do
      argument :org, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListOrgRepos
    end
  end
end
```

**Step 2: Create Pull resource**

```elixir
# lib/greenlight/github/pull.ex
defmodule Greenlight.GitHub.Pull do
  @moduledoc """
  A GitHub pull request.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :number, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :title, :string, public?: true
    attribute :head_sha, :string, public?: true
    attribute :state, :string, public?: true
    attribute :html_url, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListPulls
    end
  end
end
```

**Step 3: Create Branch resource**

```elixir
# lib/greenlight/github/branch.ex
defmodule Greenlight.GitHub.Branch do
  @moduledoc """
  A GitHub branch.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :sha, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListBranches
    end
  end
end
```

**Step 4: Create Release resource**

```elixir
# lib/greenlight/github/release.ex
defmodule Greenlight.GitHub.Release do
  @moduledoc """
  A GitHub release.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :tag_name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :html_url, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListReleases
    end
  end
end
```

**Step 5: Verify compilation**

Run: `mix compile`
Expected: Compiles with warnings about missing action modules.

**Step 6: Commit**

```
feat: add Ash resources for Repository, Pull, Branch, Release
```

---

## Task 4: Create Ash Resources — User, UserPR, UserCommit

**Files:**
- Create: `lib/greenlight/github/user.ex`
- Create: `lib/greenlight/github/user_pr.ex`
- Create: `lib/greenlight/github/user_commit.ex`

**Step 1: Create User resource**

```elixir
# lib/greenlight/github/user.ex
defmodule Greenlight.GitHub.User do
  @moduledoc """
  An authenticated GitHub user.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :login, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :avatar_url, :string, public?: true
  end

  actions do
    read :me do
      manual Greenlight.GitHub.Actions.GetAuthenticatedUser
    end
  end
end
```

**Step 2: Create UserPR resource**

```elixir
# lib/greenlight/github/user_pr.ex
defmodule Greenlight.GitHub.UserPR do
  @moduledoc """
  A pull request authored by the authenticated user (from GitHub search).
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :html_url, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :number, :integer, public?: true
    attribute :title, :string, public?: true
    attribute :state, :string, public?: true
    attribute :updated_at, :string, public?: true
    attribute :repo, :string, public?: true
  end

  actions do
    read :list do
      argument :username, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListUserPRs
    end
  end
end
```

**Step 3: Create UserCommit resource**

```elixir
# lib/greenlight/github/user_commit.ex
defmodule Greenlight.GitHub.UserCommit do
  @moduledoc """
  A commit authored by the authenticated user (from GitHub search).
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :sha, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :message, :string, public?: true
    attribute :repo, :string, public?: true
    attribute :html_url, :string, public?: true
    attribute :authored_at, :string, public?: true
  end

  actions do
    read :list do
      argument :username, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListUserCommits
    end
  end
end
```

**Step 4: Verify compilation**

Run: `mix compile`
Expected: Compiles with warnings about missing action modules.

**Step 5: Commit**

```
feat: add Ash resources for User, UserPR, UserCommit
```

---

## Task 5: Create the Domain Module

**Files:**
- Create: `lib/greenlight/github/domain.ex`

**Step 1: Create the Ash Domain**

```elixir
# lib/greenlight/github/domain.ex
defmodule Greenlight.GitHub do
  @moduledoc """
  Ash Domain for GitHub API resources.
  All GitHub data access goes through this domain.
  """

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

**IMPORTANT:** This creates a module named `Greenlight.GitHub` which will conflict with the existing `lib/greenlight/github/` directory namespace. This is fine in Elixir — a module and directory can share a name. However, we must **not** have any other file that defines `defmodule Greenlight.GitHub`. Check that no such file exists.

**Step 2: Verify compilation**

Run: `mix compile`
Expected: Compiles. Warnings about missing ManualRead action modules are expected.

**Step 3: Commit**

```
feat: add Ash domain with code interface for all GitHub resources
```

---

## Task 6: Create ManualRead Action Modules — Core Pipeline

**Files:**
- Create: `lib/greenlight/github/actions/list_workflow_runs.ex`
- Create: `lib/greenlight/github/actions/get_workflow_run.ex`
- Create: `lib/greenlight/github/actions/list_jobs.ex`

These actions call the existing `GitHub.Client` functions and convert the Model structs to Ash resource structs. This is temporary — Client will be updated to return raw maps in the cleanup task.

**Step 1: Create shared parsing helpers**

```elixir
# lib/greenlight/github/actions/parsing.ex
defmodule Greenlight.GitHub.Actions.Parsing do
  @moduledoc false

  def parse_status(nil), do: nil
  def parse_status("queued"), do: :queued
  def parse_status("in_progress"), do: :in_progress
  def parse_status("completed"), do: :completed
  def parse_status(other) when is_binary(other), do: String.to_existing_atom(other)
  def parse_status(other) when is_atom(other), do: other

  def parse_conclusion(nil), do: nil
  def parse_conclusion("success"), do: :success
  def parse_conclusion("failure"), do: :failure
  def parse_conclusion("cancelled"), do: :cancelled
  def parse_conclusion("skipped"), do: :skipped
  def parse_conclusion(other) when is_binary(other), do: String.to_existing_atom(other)
  def parse_conclusion(other) when is_atom(other), do: other

  def parse_datetime(nil), do: nil

  def parse_datetime(%DateTime{} = dt), do: dt

  def parse_datetime(str) when is_binary(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end
end
```

**Step 2: Create ListWorkflowRuns action**

```elixir
# lib/greenlight/github/actions/list_workflow_runs.ex
defmodule Greenlight.GitHub.Actions.ListWorkflowRuns do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client
  alias Greenlight.GitHub.Actions.Parsing

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    opts =
      [:head_sha, :event, :per_page]
      |> Enum.map(fn key -> {key, Map.get(query.arguments, key)} end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case Client.list_workflow_runs(owner, repo, opts) do
      {:ok, runs} ->
        ash_runs = Enum.map(runs, &to_resource(&1, owner, repo))
        {:ok, ash_runs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(run, owner, repo) do
    %Greenlight.GitHub.WorkflowRun{
      id: run.id,
      name: run.name,
      workflow_id: run.workflow_id,
      status: Parsing.parse_status(run.status),
      conclusion: Parsing.parse_conclusion(run.conclusion),
      head_sha: run.head_sha,
      event: run.event,
      html_url: run.html_url,
      path: run.path,
      created_at: Parsing.parse_datetime(run.created_at),
      updated_at: Parsing.parse_datetime(run.updated_at),
      owner: owner,
      repo: repo,
      jobs: []
    }
  end
end
```

**Step 3: Create GetWorkflowRun action**

```elixir
# lib/greenlight/github/actions/get_workflow_run.ex
defmodule Greenlight.GitHub.Actions.GetWorkflowRun do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client
  alias Greenlight.GitHub.Actions.Parsing

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo
    run_id = query.arguments.run_id

    # Reuse list_workflow_runs since GitHub API doesn't have a direct get-by-id
    # that returns the same shape. We filter client-side.
    case Client.list_workflow_runs(owner, repo, []) do
      {:ok, runs} ->
        ash_runs =
          runs
          |> Enum.filter(&(&1.id == run_id))
          |> Enum.map(&to_resource(&1, owner, repo))

        {:ok, ash_runs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(run, owner, repo) do
    %Greenlight.GitHub.WorkflowRun{
      id: run.id,
      name: run.name,
      workflow_id: run.workflow_id,
      status: Parsing.parse_status(run.status),
      conclusion: Parsing.parse_conclusion(run.conclusion),
      head_sha: run.head_sha,
      event: run.event,
      html_url: run.html_url,
      path: run.path,
      created_at: Parsing.parse_datetime(run.created_at),
      updated_at: Parsing.parse_datetime(run.updated_at),
      owner: owner,
      repo: repo,
      jobs: []
    }
  end
end
```

**Step 4: Create ListJobs action**

```elixir
# lib/greenlight/github/actions/list_jobs.ex
defmodule Greenlight.GitHub.Actions.ListJobs do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client
  alias Greenlight.GitHub.Actions.Parsing

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo
    run_id = query.arguments.run_id

    case Client.list_jobs(owner, repo, run_id) do
      {:ok, jobs} ->
        ash_jobs = Enum.map(jobs, &to_resource(&1, owner, repo, run_id))
        {:ok, ash_jobs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(job, owner, repo, run_id) do
    steps =
      Enum.map(job.steps, fn step ->
        %Greenlight.GitHub.Step{
          name: step.name,
          status: Parsing.parse_status(step.status),
          conclusion: Parsing.parse_conclusion(step.conclusion),
          number: step.number,
          started_at: Parsing.parse_datetime(step.started_at),
          completed_at: Parsing.parse_datetime(step.completed_at)
        }
      end)

    %Greenlight.GitHub.Job{
      id: job.id,
      name: job.name,
      status: Parsing.parse_status(job.status),
      conclusion: Parsing.parse_conclusion(job.conclusion),
      started_at: Parsing.parse_datetime(job.started_at),
      completed_at: Parsing.parse_datetime(job.completed_at),
      current_step: job.current_step,
      html_url: job.html_url,
      steps: steps,
      needs: job.needs || [],
      owner: owner,
      repo: repo,
      run_id: run_id
    }
  end
end
```

**Step 5: Verify compilation**

Run: `mix compile`
Expected: Compiles cleanly (or with warnings about other missing action modules only).

**Step 6: Commit**

```
feat: add ManualRead actions for WorkflowRun and Job resources
```

---

## Task 7: Create ManualRead Action Modules — Browsing and User Resources

**Files:**
- Create: `lib/greenlight/github/actions/list_org_repos.ex`
- Create: `lib/greenlight/github/actions/list_pulls.ex`
- Create: `lib/greenlight/github/actions/list_branches.ex`
- Create: `lib/greenlight/github/actions/list_releases.ex`
- Create: `lib/greenlight/github/actions/get_authenticated_user.ex`
- Create: `lib/greenlight/github/actions/list_user_prs.ex`
- Create: `lib/greenlight/github/actions/list_user_commits.ex`

**Step 1: Create ListOrgRepos action**

```elixir
# lib/greenlight/github/actions/list_org_repos.ex
defmodule Greenlight.GitHub.Actions.ListOrgRepos do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    org = query.arguments.org

    case Client.list_org_repos(org) do
      {:ok, full_names} ->
        repos =
          Enum.map(full_names, fn full_name ->
            [owner, name] = String.split(full_name, "/", parts: 2)

            %Greenlight.GitHub.Repository{
              full_name: full_name,
              name: name,
              owner: owner
            }
          end)

        {:ok, repos}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 2: Create ListPulls action**

```elixir
# lib/greenlight/github/actions/list_pulls.ex
defmodule Greenlight.GitHub.Actions.ListPulls do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_pulls(owner, repo) do
      {:ok, pulls} ->
        ash_pulls =
          Enum.map(pulls, fn pr ->
            %Greenlight.GitHub.Pull{
              number: pr.number,
              title: pr.title,
              head_sha: pr.head_sha
            }
          end)

        {:ok, ash_pulls}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 3: Create ListBranches action**

```elixir
# lib/greenlight/github/actions/list_branches.ex
defmodule Greenlight.GitHub.Actions.ListBranches do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_branches(owner, repo) do
      {:ok, branches} ->
        ash_branches =
          Enum.map(branches, fn b ->
            %Greenlight.GitHub.Branch{
              name: b.name,
              sha: b.sha
            }
          end)

        {:ok, ash_branches}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 4: Create ListReleases action**

```elixir
# lib/greenlight/github/actions/list_releases.ex
defmodule Greenlight.GitHub.Actions.ListReleases do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_releases(owner, repo) do
      {:ok, releases} ->
        ash_releases =
          Enum.map(releases, fn r ->
            %Greenlight.GitHub.Release{
              tag_name: r.tag_name,
              name: r.name
            }
          end)

        {:ok, ash_releases}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 5: Create GetAuthenticatedUser action**

```elixir
# lib/greenlight/github/actions/get_authenticated_user.ex
defmodule Greenlight.GitHub.Actions.GetAuthenticatedUser do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(_query, _data_layer_query, _opts, _context) do
    case Client.get_authenticated_user() do
      {:ok, user} ->
        {:ok,
         [
           %Greenlight.GitHub.User{
             login: user.login,
             name: user.name,
             avatar_url: user.avatar_url
           }
         ]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 6: Create ListUserPRs action**

```elixir
# lib/greenlight/github/actions/list_user_prs.ex
defmodule Greenlight.GitHub.Actions.ListUserPRs do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    username = query.arguments.username

    case Client.search_user_prs(username) do
      {:ok, prs} ->
        ash_prs =
          Enum.map(prs, fn pr ->
            %Greenlight.GitHub.UserPR{
              number: pr.number,
              title: pr.title,
              state: pr.state,
              html_url: pr.html_url,
              updated_at: pr.updated_at,
              repo: pr.repo
            }
          end)

        {:ok, ash_prs}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 7: Create ListUserCommits action**

```elixir
# lib/greenlight/github/actions/list_user_commits.ex
defmodule Greenlight.GitHub.Actions.ListUserCommits do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    username = query.arguments.username

    case Client.search_user_commits(username) do
      {:ok, commits} ->
        ash_commits =
          Enum.map(commits, fn c ->
            %Greenlight.GitHub.UserCommit{
              sha: c.sha,
              message: c.message,
              repo: c.repo,
              html_url: c.html_url,
              authored_at: c.authored_at
            }
          end)

        {:ok, ash_commits}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 8: Verify compilation**

Run: `mix compile`
Expected: Compiles cleanly. All action modules now exist.

**Step 9: Commit**

```
feat: add ManualRead actions for browsing and user resources
```

---

## Task 8: Write Tests for the Ash Domain Interface

**Files:**
- Create: `test/greenlight/github/domain_test.exs`

Tests use the existing `Req.Test` mock infrastructure. Each domain function is tested against mocked API responses.

**Step 1: Write domain integration tests**

```elixir
# test/greenlight/github/domain_test.exs
defmodule Greenlight.GitHub.DomainTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub

  setup do
    # Enable Req test mode
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      route(conn)
    end)

    :ok
  end

  defp route(%Plug.Conn{request_path: "/repos/owner/repo/actions/runs"} = conn) do
    Req.Test.json(conn, %{
      "workflow_runs" => [
        %{
          "id" => 123,
          "name" => "CI",
          "workflow_id" => 456,
          "status" => "in_progress",
          "conclusion" => nil,
          "head_sha" => "abc123",
          "event" => "push",
          "html_url" => "https://github.com/owner/repo/actions/runs/123",
          "path" => ".github/workflows/ci.yml",
          "created_at" => "2026-02-12T10:00:00Z",
          "updated_at" => "2026-02-12T10:01:00Z"
        }
      ]
    })
  end

  defp route(%Plug.Conn{request_path: "/repos/owner/repo/actions/runs/123/jobs"} = conn) do
    Req.Test.json(conn, %{
      "jobs" => [
        %{
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
            }
          ]
        }
      ]
    })
  end

  defp route(%Plug.Conn{request_path: "/repos/owner/repo/pulls"} = conn) do
    Req.Test.json(conn, [
      %{"number" => 42, "title" => "Fix bug", "head" => %{"sha" => "def456"}}
    ])
  end

  defp route(%Plug.Conn{request_path: "/repos/owner/repo/branches"} = conn) do
    Req.Test.json(conn, [
      %{"name" => "main", "commit" => %{"sha" => "abc123"}}
    ])
  end

  defp route(%Plug.Conn{request_path: "/repos/owner/repo/releases"} = conn) do
    Req.Test.json(conn, [
      %{"tag_name" => "v1.0.0", "name" => "Release 1.0"}
    ])
  end

  defp route(%Plug.Conn{request_path: "/orgs/myorg/repos"} = conn) do
    Req.Test.json(conn, [
      %{"full_name" => "myorg/repo1"},
      %{"full_name" => "myorg/repo2"}
    ])
  end

  defp route(%Plug.Conn{request_path: "/user"} = conn) do
    Req.Test.json(conn, %{
      "login" => "testuser",
      "name" => "Test User",
      "avatar_url" => "https://avatars.githubusercontent.com/u/123"
    })
  end

  defp route(%Plug.Conn{request_path: "/search/issues"} = conn) do
    Req.Test.json(conn, %{
      "items" => [
        %{
          "number" => 10,
          "title" => "My PR",
          "state" => "open",
          "html_url" => "https://github.com/org/repo/pull/10",
          "updated_at" => "2026-02-12T10:00:00Z",
          "repository_url" => "https://api.github.com/repos/org/repo"
        }
      ]
    })
  end

  defp route(%Plug.Conn{request_path: "/search/commits"} = conn) do
    Req.Test.json(conn, %{
      "items" => [
        %{
          "sha" => "abc123",
          "commit" => %{
            "message" => "fix: something\n\nDetails here",
            "author" => %{"date" => "2026-02-12T10:00:00Z"}
          },
          "repository" => %{"full_name" => "org/repo"},
          "html_url" => "https://github.com/org/repo/commit/abc123"
        }
      ]
    })
  end

  describe "list_workflow_runs!/2" do
    test "returns WorkflowRun resources" do
      runs = GitHub.list_workflow_runs!("owner", "repo")

      assert [%Greenlight.GitHub.WorkflowRun{} = run] = runs
      assert run.id == 123
      assert run.name == "CI"
      assert run.status == :in_progress
      assert run.owner == "owner"
      assert run.repo == "repo"
    end
  end

  describe "list_jobs!/3" do
    test "returns Job resources with embedded steps" do
      jobs = GitHub.list_jobs!("owner", "repo", 123)

      assert [%Greenlight.GitHub.Job{} = job] = jobs
      assert job.id == 789
      assert job.name == "build"
      assert job.status == :completed
      assert job.conclusion == :success
      assert job.owner == "owner"
      assert job.run_id == 123
      assert [%Greenlight.GitHub.Step{name: "Checkout"}] = job.steps
    end
  end

  describe "list_pulls!/2" do
    test "returns Pull resources" do
      pulls = GitHub.list_pulls!("owner", "repo")

      assert [%Greenlight.GitHub.Pull{number: 42, title: "Fix bug", head_sha: "def456"}] = pulls
    end
  end

  describe "list_branches!/2" do
    test "returns Branch resources" do
      branches = GitHub.list_branches!("owner", "repo")

      assert [%Greenlight.GitHub.Branch{name: "main", sha: "abc123"}] = branches
    end
  end

  describe "list_releases!/2" do
    test "returns Release resources" do
      releases = GitHub.list_releases!("owner", "repo")

      assert [%Greenlight.GitHub.Release{tag_name: "v1.0.0", name: "Release 1.0"}] = releases
    end
  end

  describe "list_org_repos!/1" do
    test "returns Repository resources" do
      repos = GitHub.list_org_repos!("myorg")

      assert [
               %Greenlight.GitHub.Repository{full_name: "myorg/repo1"},
               %Greenlight.GitHub.Repository{full_name: "myorg/repo2"}
             ] = repos
    end
  end

  describe "get_authenticated_user!/0" do
    test "returns a User resource" do
      user = GitHub.get_authenticated_user!()

      assert %Greenlight.GitHub.User{login: "testuser", name: "Test User"} = user
    end
  end

  describe "list_user_prs!/1" do
    test "returns UserPR resources" do
      prs = GitHub.list_user_prs!("testuser")

      assert [%Greenlight.GitHub.UserPR{number: 10, title: "My PR", repo: "org/repo"}] = prs
    end
  end

  describe "list_user_commits!/1" do
    test "returns UserCommit resources" do
      commits = GitHub.list_user_commits!("testuser")

      assert [%Greenlight.GitHub.UserCommit{sha: "abc123", repo: "org/repo"}] = commits
    end
  end
end
```

**Step 2: Run the tests**

Run: `mix test test/greenlight/github/domain_test.exs`
Expected: All tests pass. If any fail, debug using the error output.

**Step 3: Commit**

```
test: add integration tests for Ash domain interface
```

---

## Task 9: Migrate Poller and WorkflowGraph

**Files:**
- Modify: `lib/greenlight/github/poller.ex`
- Modify: `lib/greenlight/github/workflow_graph.ex`

**Step 1: Update WorkflowGraph to use Ash resource structs**

In `lib/greenlight/github/workflow_graph.ex`:

- Line 6: Change `alias Greenlight.GitHub.Models` to `alias Greenlight.GitHub.{WorkflowRun, Job}`
- Line 53: Change `defp workflow_to_node(%Models.WorkflowRun{} = run)` to `defp workflow_to_node(%WorkflowRun{} = run)`
- Line 80: Change `defp job_to_node(%Models.Job{} = job)` to `defp job_to_node(%Job{} = job)`

The rest of the functions access struct fields by name (e.g., `run.id`, `job.name`) which work identically on Ash resource structs.

**Step 2: Update Poller to use the Ash domain**

In `lib/greenlight/github/poller.ex`:

- Line 10: Change `alias Greenlight.GitHub.{Client, WorkflowGraph}` to `alias Greenlight.GitHub.{Client, WorkflowGraph, WorkflowRun, Job}`
- Lines 112-113: Replace the Client calls in `do_poll/1`:

```elixir
# Before (lines 112-113):
with {:ok, runs} <- Client.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
     runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do

# After:
with {:ok, runs} <- Greenlight.GitHub.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
     runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do
```

Note: We use `list_workflow_runs/3` (non-bang, returns `{:ok, _}` or `{:error, _}`) since the Poller needs to handle errors gracefully. Check the Ash domain code interface docs — `define` generates both `list_workflow_runs!/3` (raises) and `list_workflow_runs/3` (returns ok/error tuple). **Verify this is the case.** If the domain only generates bang versions, wrap the call in a try or use `Ash.read` directly.

- Lines 156-163: Update `fetch_jobs_for_runs/3`:

```elixir
# Before:
defp fetch_jobs_for_runs(owner, repo, runs) do
  Enum.map(runs, fn run ->
    case Client.list_jobs(owner, repo, run.id) do
      {:ok, jobs} -> %{run | jobs: jobs}
      {:error, _} -> run
    end
  end)
end

# After:
defp fetch_jobs_for_runs(owner, repo, runs) do
  Enum.map(runs, fn run ->
    case Greenlight.GitHub.list_jobs(owner, repo, run.id) do
      {:ok, jobs} -> %{run | jobs: jobs}
      {:error, _} -> run
    end
  end)
end
```

- Line 180: `Client.get_repo_content/4` call stays — this is a utility function not modeled as a resource.

**Step 3: Run existing tests**

Run: `mix test test/greenlight/github/poller_test.exs test/greenlight/github/workflow_graph_test.exs`
Expected: Tests pass. If tests reference `Models.*` structs directly, update those references.

**Step 4: Commit**

```
refactor: migrate Poller and WorkflowGraph to use Ash domain
```

---

## Task 10: Migrate UserInsightsServer

**Files:**
- Modify: `lib/greenlight/github/user_insights_server.ex`

**Step 1: Update imports and the fetch function**

In `lib/greenlight/github/user_insights_server.ex`:

- Remove: `alias Greenlight.GitHub.Client` (line ~8-ish, wherever the alias is)
- Update `fetch_user_insights/0` (around line 67):

```elixir
# Before:
defp fetch_user_insights do
  case Client.get_authenticated_user() do
    {:ok, user} ->
      tasks = [
        Task.async(fn -> Client.search_user_prs(user.login) end),
        Task.async(fn -> Client.search_user_commits(user.login) end)
      ]

      [{:ok, prs}, {:ok, commits}] = Task.await_many(tasks, 15_000)
      %{user: user, prs: prs, commits: commits, loading: false}

    {:error, _} ->
      %{user: nil, prs: [], commits: [], loading: false}
  end
end

# After:
defp fetch_user_insights do
  case Greenlight.GitHub.get_authenticated_user() do
    {:ok, user} ->
      tasks = [
        Task.async(fn -> Greenlight.GitHub.list_user_prs(user.login) end),
        Task.async(fn -> Greenlight.GitHub.list_user_commits(user.login) end)
      ]

      [{:ok, prs}, {:ok, commits}] = Task.await_many(tasks, 15_000)
      %{user: user, prs: prs, commits: commits, loading: false}

    {:error, _} ->
      %{user: nil, prs: [], commits: [], loading: false}
  end
end
```

**Important:** The `get_authenticated_user` domain function (non-bang) should return `{:ok, %User{}}` or `{:error, _}`. Verify the Ash code interface returns a single resource for `get?` actions vs a list. You may need to adjust based on Ash's behavior — `get_authenticated_user` might need `get? true` on the read action, or the domain `define` might need additional config.

**Step 2: Verify tests pass**

Run: `mix test`
Expected: All tests pass.

**Step 3: Commit**

```
refactor: migrate UserInsightsServer to use Ash domain
```

---

## Task 11: Migrate LiveViews

**Files:**
- Modify: `lib/greenlight_web/live/pipeline_live.ex`
- Modify: `lib/greenlight_web/live/dashboard_live.ex`
- Modify: `lib/greenlight_web/live/repo_live.ex`

**Step 1: Update PipelineLive**

In `lib/greenlight_web/live/pipeline_live.ex`:

- Remove `alias Greenlight.GitHub.Client`
- Line 56 (PR mount): Change `Client.list_pulls(owner, repo)` to:
  ```elixir
  case Greenlight.GitHub.list_pulls(owner, repo) do
    {:ok, pulls} -> pulls
    {:error, _} -> []
  end
  ```
  Then find the PR in `pulls` by matching on `pr.number` (same field name on the Ash struct).

- Line 86 (Release mount): Change `Client.list_workflow_runs(owner, repo, event: "release")` to:
  ```elixir
  case Greenlight.GitHub.list_workflow_runs(owner, repo, event: "release") do
    {:ok, runs} -> runs
    {:error, _} -> []
  end
  ```

Adjust the pattern matching as needed — the field names on Ash resource structs are the same as the old Model structs.

**Step 2: Update DashboardLive**

In `lib/greenlight_web/live/dashboard_live.ex`:

- Remove `alias Greenlight.GitHub.Client`
- Line 51 (handle_info :load_org_repos): Change `Client.list_org_repos(org)` to `Greenlight.GitHub.list_org_repos(org)`. Note: the domain function returns `{:ok, [%Repository{}]}`. Update the consumer to extract `full_name` from each Repository struct rather than using the string directly.

  Before: The result was `{:ok, ["org/repo1", "org/repo2"]}` — plain strings.
  After: The result is `{:ok, [%Repository{full_name: "org/repo1"}, ...]}` — structs.

  The template that renders repo links will need to access `repo.full_name` instead of using the string directly. **Check the template to see how repos are rendered and update accordingly.**

**Step 3: Update RepoLive**

In `lib/greenlight_web/live/repo_live.ex`:

- Remove `alias Greenlight.GitHub.Client`
- Lines 43-62 (handle_info :load_data): Replace all Client calls:

```elixir
# Before:
{:ok, pulls} = Client.list_pulls(owner, repo)
{:ok, branches} = Client.list_branches(owner, repo)
{:ok, releases} = Client.list_releases(owner, repo)
{:ok, runs} = Client.list_workflow_runs(owner, repo, per_page: 20)

# After:
{:ok, pulls} = Greenlight.GitHub.list_pulls(owner, repo)
{:ok, branches} = Greenlight.GitHub.list_branches(owner, repo)
{:ok, releases} = Greenlight.GitHub.list_releases(owner, repo)
{:ok, runs} = Greenlight.GitHub.list_workflow_runs(owner, repo, per_page: 20)
```

The template accesses fields like `run.head_sha`, `pr.number`, `branch.sha`, `release.tag_name` — all of which exist on the Ash resource structs with the same names.

**Step 4: Run all tests**

Run: `mix test`
Expected: All tests pass. If LiveView tests reference old struct shapes, update them.

**Step 5: Commit**

```
refactor: migrate LiveViews to use Ash domain
```

---

## Task 12: Cleanup — Delete Models, Update Client

**Files:**
- Delete: `lib/greenlight/github/models.ex`
- Delete: `test/greenlight/github/models_test.exs`
- Modify: `lib/greenlight/github/client.ex` — remove Models dependency, return raw maps

**Step 1: Update Client to return raw maps**

In `lib/greenlight/github/client.ex`:

- Line 6: Remove `alias Greenlight.GitHub.Models`
- Lines 34-37: Update `list_workflow_runs` to return raw API maps:

```elixir
# Before:
{:ok, %{status: 200, body: body}} ->
  runs = Enum.map(body["workflow_runs"], &Models.WorkflowRun.from_api/1)
  {:ok, runs}

# After:
{:ok, %{status: 200, body: body}} ->
  {:ok, body["workflow_runs"]}
```

- Lines 49-51: Update `list_jobs` to return raw API maps:

```elixir
# Before:
{:ok, %{status: 200, body: body}} ->
  jobs = Enum.map(body["jobs"], &Models.Job.from_api/1)
  {:ok, jobs}

# After:
{:ok, %{status: 200, body: body}} ->
  {:ok, body["jobs"]}
```

All other Client functions already return raw maps — no changes needed.

**Step 2: Update ManualRead actions for raw map input**

Now that Client returns raw maps instead of Model structs, update the ManualRead actions to parse from raw maps:

In `lib/greenlight/github/actions/list_workflow_runs.ex`, update `to_resource/3`:

```elixir
defp to_resource(run, owner, repo) do
  %Greenlight.GitHub.WorkflowRun{
    id: run["id"],
    name: run["name"],
    workflow_id: run["workflow_id"],
    status: Parsing.parse_status(run["status"]),
    conclusion: Parsing.parse_conclusion(run["conclusion"]),
    head_sha: run["head_sha"],
    event: run["event"],
    html_url: run["html_url"],
    path: run["path"],
    created_at: Parsing.parse_datetime(run["created_at"]),
    updated_at: Parsing.parse_datetime(run["updated_at"]),
    owner: owner,
    repo: repo,
    jobs: []
  }
end
```

In `lib/greenlight/github/actions/get_workflow_run.ex`, same change to `to_resource/3` (use string keys).

In `lib/greenlight/github/actions/list_jobs.ex`, update `to_resource/4`:

```elixir
defp to_resource(job, owner, repo, run_id) do
  steps =
    Enum.map(job["steps"] || [], fn step ->
      %Greenlight.GitHub.Step{
        name: step["name"],
        status: Parsing.parse_status(step["status"]),
        conclusion: Parsing.parse_conclusion(step["conclusion"]),
        number: step["number"],
        started_at: Parsing.parse_datetime(step["started_at"]),
        completed_at: Parsing.parse_datetime(step["completed_at"])
      }
    end)

  current_step =
    steps
    |> Enum.find(&(&1.status == :in_progress))
    |> case do
      nil -> nil
      step -> step.name
    end

  %Greenlight.GitHub.Job{
    id: job["id"],
    name: job["name"],
    status: Parsing.parse_status(job["status"]),
    conclusion: Parsing.parse_conclusion(job["conclusion"]),
    started_at: Parsing.parse_datetime(job["started_at"]),
    completed_at: Parsing.parse_datetime(job["completed_at"]),
    current_step: current_step,
    html_url: job["html_url"],
    steps: steps,
    needs: [],
    owner: owner,
    repo: repo,
    run_id: run_id
  }
end
```

**Note:** The browsing/user ManualRead actions (ListPulls, ListBranches, etc.) already work with raw maps from Client, so they need no changes.

**Step 3: Delete old Models**

Delete `lib/greenlight/github/models.ex` and `test/greenlight/github/models_test.exs`.

**Step 4: Remove stale references**

Search the codebase for any remaining references to `Greenlight.GitHub.Models`, `Models.WorkflowRun`, `Models.Job`, or `Models.Step`. Fix any that remain.

Run: `grep -r "GitHub.Models\|Models.WorkflowRun\|Models.Job\|Models.Step" lib/ test/`

**Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 6: Commit**

```
refactor: remove Models module, update Client to return raw maps
```

---

## Task 13: Full Verification and Nix Build

**Step 1: Run precommit checks**

Run: `mix precommit`

This runs: `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `test`, and `nix build .#dockerImage`.

Expected: All checks pass.

**Step 2: If dep hash changed, update nix/package.nix**

If `nix build .#default` fails with a hash mismatch, update the hash in `nix/package.nix` with the new `got:` value. Then re-run:

Run: `nix build .#default && nix build .#dockerImage`
Expected: Both builds succeed.

**Step 3: Final commit if nix changes were needed**

```
chore: update nix dep hash for ash dependency
```

**Step 4: Run the dev server and verify manually**

Run: `mix phx.server`

Verify:
- Dashboard loads and shows user insights, bookmarked repos, org repos
- Click into a repo — pulls, branches, releases, commits tabs all load
- Click into a commit — pipeline DAG viewer loads and updates in real-time
- No errors in the terminal logs

---

## Summary of Commits

1. `feat: add ash framework dependency`
2. `feat: add core Ash resources for WorkflowRun, Job, Step`
3. `feat: add Ash resources for Repository, Pull, Branch, Release`
4. `feat: add Ash resources for User, UserPR, UserCommit`
5. `feat: add Ash domain with code interface for all GitHub resources`
6. `feat: add ManualRead actions for WorkflowRun and Job resources`
7. `feat: add ManualRead actions for browsing and user resources`
8. `test: add integration tests for Ash domain interface`
9. `refactor: migrate Poller and WorkflowGraph to use Ash domain`
10. `refactor: migrate UserInsightsServer to use Ash domain`
11. `refactor: migrate LiveViews to use Ash domain`
12. `refactor: remove Models module, update Client to return raw maps`
13. `chore: update nix dep hash for ash dependency` (if needed)
