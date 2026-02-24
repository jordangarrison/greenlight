# User Insights Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a user activity section to the top of the dashboard showing the authenticated GitHub user's profile, recent PRs, and recent commits.

**Architecture:** Fetch the authenticated user via `GET /user`, then use GitHub Search API to find their recent PRs and commits. Data loads asynchronously after LiveView connects. New client functions follow existing Req patterns.

**Tech Stack:** Elixir, Phoenix LiveView, Req HTTP client, GitHub REST/Search API, Tailwind CSS v4

---

### Task 1: Add `get_authenticated_user/0` to Client

**Files:**
- Modify: `lib/greenlight/github/client.ex`
- Modify: `test/greenlight/github/client_test.exs`

**Step 1: Write the failing test**

Add to the `setup` stub in `test/greenlight/github/client_test.exs`, inside the `case conn.request_path` block, add a new clause before the final `end`:

```elixir
"/user" ->
  Req.Test.json(conn, %{
    "login" => "testuser",
    "name" => "Test User",
    "avatar_url" => "https://avatars.githubusercontent.com/u/12345"
  })
```

Then add the test:

```elixir
test "get_authenticated_user/0 returns user profile" do
  {:ok, user} = Client.get_authenticated_user()
  assert user.login == "testuser"
  assert user.name == "Test User"
  assert user.avatar_url == "https://avatars.githubusercontent.com/u/12345"
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: FAIL — `get_authenticated_user/0 is undefined`

**Step 3: Write minimal implementation**

Add to `lib/greenlight/github/client.ex` after the existing functions:

```elixir
def get_authenticated_user do
  case Req.get(new(), url: "/user") do
    {:ok, %{status: 200, body: body}} ->
      {:ok,
       %{
         login: body["login"],
         name: body["name"],
         avatar_url: body["avatar_url"]
       }}

    {:ok, %{status: status, body: body}} ->
      {:error, {status, body}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/greenlight/github/client.ex test/greenlight/github/client_test.exs
git commit -m "feat: add get_authenticated_user/0 to GitHub client"
```

---

### Task 2: Add `search_user_prs/1` to Client

**Files:**
- Modify: `lib/greenlight/github/client.ex`
- Modify: `test/greenlight/github/client_test.exs`

**Step 1: Write the failing test**

Add to the `setup` stub's `case` block in `test/greenlight/github/client_test.exs`:

```elixir
"/search/issues" ->
  Req.Test.json(conn, %{
    "items" => [
      %{
        "number" => 99,
        "title" => "Fix bug",
        "state" => "open",
        "html_url" => "https://github.com/owner/repo/pull/99",
        "updated_at" => "2026-02-19T10:00:00Z",
        "pull_request" => %{"html_url" => "https://github.com/owner/repo/pull/99"},
        "repository_url" => "https://api.github.com/repos/owner/repo"
      }
    ]
  })
```

Then add the test:

```elixir
test "search_user_prs/1 returns recent PRs for user" do
  {:ok, prs} = Client.search_user_prs("testuser")
  assert [pr] = prs
  assert pr.number == 99
  assert pr.title == "Fix bug"
  assert pr.state == "open"
  assert pr.repo == "owner/repo"
  assert pr.html_url == "https://github.com/owner/repo/pull/99"
  assert pr.updated_at == "2026-02-19T10:00:00Z"
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: FAIL — `search_user_prs/1 is undefined`

**Step 3: Write minimal implementation**

Add to `lib/greenlight/github/client.ex`:

```elixir
def search_user_prs(username) do
  case Req.get(new(),
         url: "/search/issues",
         params: %{q: "author:#{username} type:pr sort:updated", per_page: 5}
       ) do
    {:ok, %{status: 200, body: body}} ->
      prs =
        Enum.map(body["items"], fn item ->
          repo =
            item["repository_url"]
            |> String.replace("https://api.github.com/repos/", "")

          %{
            number: item["number"],
            title: item["title"],
            state: item["state"],
            html_url: item["html_url"],
            updated_at: item["updated_at"],
            repo: repo
          }
        end)

      {:ok, prs}

    {:ok, %{status: status, body: body}} ->
      {:error, {status, body}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/greenlight/github/client.ex test/greenlight/github/client_test.exs
git commit -m "feat: add search_user_prs/1 to GitHub client"
```

---

### Task 3: Add `search_user_commits/1` to Client

**Files:**
- Modify: `lib/greenlight/github/client.ex`
- Modify: `test/greenlight/github/client_test.exs`

**Step 1: Write the failing test**

Add to the `setup` stub's `case` block. Note: the commit search API requires the `application/vnd.github.cloak-preview+json` accept header, but the existing `new/0` already sends `application/vnd.github+json` which works for search. Add the stub:

```elixir
"/search/commits" ->
  Req.Test.json(conn, %{
    "items" => [
      %{
        "sha" => "abc1234567890",
        "html_url" => "https://github.com/owner/repo/commit/abc1234567890",
        "commit" => %{
          "message" => "Fix the thing\n\nDetailed description",
          "author" => %{
            "date" => "2026-02-19T09:00:00Z"
          }
        },
        "repository" => %{
          "full_name" => "owner/repo"
        }
      }
    ]
  })
```

Then add the test:

```elixir
test "search_user_commits/1 returns recent commits for user" do
  {:ok, commits} = Client.search_user_commits("testuser")
  assert [commit] = commits
  assert commit.sha == "abc1234567890"
  assert commit.message == "Fix the thing"
  assert commit.repo == "owner/repo"
  assert commit.html_url == "https://github.com/owner/repo/commit/abc1234567890"
  assert commit.authored_at == "2026-02-19T09:00:00Z"
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: FAIL — `search_user_commits/1 is undefined`

**Step 3: Write minimal implementation**

Add to `lib/greenlight/github/client.ex`:

```elixir
def search_user_commits(username) do
  case Req.get(new(),
         url: "/search/commits",
         params: %{q: "author:#{username} sort:author-date", per_page: 5}
       ) do
    {:ok, %{status: 200, body: body}} ->
      commits =
        Enum.map(body["items"], fn item ->
          # Take only the first line of the commit message
          message =
            item["commit"]["message"]
            |> String.split("\n", parts: 2)
            |> List.first()

          %{
            sha: item["sha"],
            message: message,
            repo: item["repository"]["full_name"],
            html_url: item["html_url"],
            authored_at: item["commit"]["author"]["date"]
          }
        end)

      {:ok, commits}

    {:ok, %{status: status, body: body}} ->
      {:error, {status, body}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/greenlight/github/client_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/greenlight/github/client.ex test/greenlight/github/client_test.exs
git commit -m "feat: add search_user_commits/1 to GitHub client"
```

---

### Task 4: Add relative time helper

**Files:**
- Create: `lib/greenlight/time_helpers.ex`
- Create: `test/greenlight/time_helpers_test.exs`

**Step 1: Write the failing test**

Create `test/greenlight/time_helpers_test.exs`:

```elixir
defmodule Greenlight.TimeHelpersTest do
  use ExUnit.Case, async: true

  alias Greenlight.TimeHelpers

  test "relative_time/1 returns 'just now' for recent timestamps" do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(now) == "just now"
  end

  test "relative_time/1 returns minutes ago" do
    past = DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "5m ago"
  end

  test "relative_time/1 returns hours ago" do
    past = DateTime.utc_now() |> DateTime.add(-7200, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "2h ago"
  end

  test "relative_time/1 returns days ago" do
    past = DateTime.utc_now() |> DateTime.add(-172_800, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "2d ago"
  end

  test "relative_time/1 returns nil for nil input" do
    assert TimeHelpers.relative_time(nil) == ""
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/time_helpers_test.exs --seed 0`
Expected: FAIL — module `Greenlight.TimeHelpers` is not available

**Step 3: Write minimal implementation**

Create `lib/greenlight/time_helpers.ex`:

```elixir
defmodule Greenlight.TimeHelpers do
  @moduledoc """
  Helpers for formatting timestamps as relative time strings.
  """

  def relative_time(nil), do: ""

  def relative_time(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} ->
        diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
        format_diff(diff)

      _ ->
        ""
    end
  end

  defp format_diff(seconds) when seconds < 60, do: "just now"
  defp format_diff(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m ago"
  defp format_diff(seconds) when seconds < 86400, do: "#{div(seconds, 3600)}h ago"
  defp format_diff(seconds), do: "#{div(seconds, 86400)}d ago"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/greenlight/time_helpers_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/greenlight/time_helpers.ex test/greenlight/time_helpers_test.exs
git commit -m "feat: add relative time helper"
```

---

### Task 5: Add user loading to DashboardLive mount and handle_info

**Files:**
- Modify: `lib/greenlight_web/live/dashboard_live.ex`

**Step 1: Update mount to add default assigns and trigger :load_user**

In `lib/greenlight_web/live/dashboard_live.ex`, replace the existing `mount/3`:

```elixir
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
      expanded_orgs: MapSet.new(),
      user: nil,
      user_prs: [],
      user_commits: [],
      user_loading: true
    )

  if connected?(socket) do
    send(self(), :load_org_repos)
    send(self(), :load_user)
  end

  {:ok, socket}
end
```

**Step 2: Add handle_info for :load_user**

Add after the existing `handle_info(:load_org_repos, ...)`:

```elixir
@impl true
def handle_info(:load_user, socket) do
  case Client.get_authenticated_user() do
    {:ok, user} ->
      send(self(), :load_user_activity)
      {:noreply, assign(socket, user: user)}

    {:error, _} ->
      {:noreply, assign(socket, user_loading: false)}
  end
end
```

**Step 3: Add handle_info for :load_user_activity**

Add after the `:load_user` handler:

```elixir
@impl true
def handle_info(:load_user_activity, socket) do
  username = socket.assigns.user.login

  prs_task = Task.async(fn -> Client.search_user_prs(username) end)
  commits_task = Task.async(fn -> Client.search_user_commits(username) end)

  prs = case Task.await(prs_task) do
    {:ok, prs} -> prs
    {:error, _} -> []
  end

  commits = case Task.await(commits_task) do
    {:ok, commits} -> commits
    {:error, _} -> []
  end

  {:noreply, assign(socket, user_prs: prs, user_commits: commits, user_loading: false)}
end
```

**Step 4: Run the full test suite to make sure nothing is broken**

Run: `mix test --seed 0`
Expected: All existing tests PASS

**Step 5: Commit**

```bash
git add lib/greenlight_web/live/dashboard_live.ex
git commit -m "feat: load authenticated user and activity in dashboard mount"
```

---

### Task 6: Add user insights section to dashboard template

**Files:**
- Modify: `lib/greenlight_web/live/dashboard_live.ex` (the `render/1` function)

**Step 1: Import TimeHelpers**

At the top of `lib/greenlight_web/live/dashboard_live.ex`, add after the `alias`:

```elixir
import Greenlight.TimeHelpers, only: [relative_time: 1]
```

**Step 2: Add user insights section to render/1**

In the `render/1` function, insert the new section **after** the `<h1>` Dashboard heading and **before** the bookmarked repos `<section>`. The full new block:

```heex
<%!-- User Insights Section --%>
<section class="mb-12">
  <%!-- Loading state --%>
  <div :if={@user_loading} class="nb-card p-6 mb-6">
    <div class="flex items-center gap-4 animate-pulse">
      <div class="w-10 h-10 bg-[var(--gl-border)] rounded-full" />
      <div class="h-4 w-48 bg-[var(--gl-border)]" />
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
      <div :for={_ <- 1..2} class="space-y-3">
        <div class="h-3 w-32 bg-[var(--gl-border)]" />
        <div :for={_ <- 1..3} class="h-10 bg-[var(--gl-border)]" />
      </div>
    </div>
  </div>

  <%!-- Loaded state --%>
  <div :if={@user != nil and not @user_loading}>
    <%!-- Compact profile bar --%>
    <div class="flex items-center gap-3 mb-6">
      <img
        src={@user.avatar_url}
        alt={@user.login}
        class="w-10 h-10 rounded-full border-2 border-[var(--gl-accent)]"
      />
      <div>
        <span class="text-lg font-bold text-white">{@user.login}</span>
        <span :if={@user.name} class="text-sm text-[var(--gl-text-muted)] ml-2">
          {" · "}{@user.name}
        </span>
      </div>
    </div>

    <%!-- Two-column grid: PRs and Commits --%>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <%!-- Recent PRs column --%>
      <div>
        <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-3 flex items-center gap-2">
          <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Pull Requests
        </h3>
        <div :if={@user_prs == []} class="text-sm text-[var(--gl-text-muted)] py-4">
          No recent pull requests
        </div>
        <div class="space-y-2">
          <a
            :for={pr <- @user_prs}
            href={pr.html_url}
            target="_blank"
            rel="noopener noreferrer"
            class="nb-card-muted block p-3 group"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0 flex-1">
                <span class="text-xs text-[var(--gl-text-muted)] block">{pr.repo}</span>
                <span class="text-sm text-white font-bold group-hover:text-[var(--gl-accent)] transition-colors block truncate">
                  {pr.title}
                </span>
              </div>
              <span class={[
                "text-xs px-1.5 py-0.5 border font-bold shrink-0",
                if(pr.state == "open",
                  do: "text-[var(--gl-status-success)] border-[var(--gl-status-success)]",
                  else: "text-[var(--gl-text-muted)] border-[var(--gl-border)]"
                )
              ]}>
                {pr.state}
              </span>
            </div>
            <div class="flex items-center gap-2 mt-1 text-xs text-[var(--gl-text-muted)]">
              <span>#{pr.number}</span>
              <span>·</span>
              <span>{relative_time(pr.updated_at)}</span>
            </div>
          </a>
        </div>
      </div>

      <%!-- Recent Commits column --%>
      <div>
        <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-3 flex items-center gap-2">
          <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Commits
        </h3>
        <div :if={@user_commits == []} class="text-sm text-[var(--gl-text-muted)] py-4">
          No recent commits
        </div>
        <div class="space-y-2">
          <a
            :for={commit <- @user_commits}
            href={commit.html_url}
            target="_blank"
            rel="noopener noreferrer"
            class="nb-card-muted block p-3 group"
          >
            <div class="min-w-0">
              <span class="text-xs text-[var(--gl-text-muted)] block">{commit.repo}</span>
              <span class="text-sm text-white font-bold group-hover:text-[var(--gl-accent)] transition-colors block truncate">
                {commit.message}
              </span>
            </div>
            <div class="flex items-center gap-2 mt-1 text-xs text-[var(--gl-text-muted)]">
              <span>{String.slice(commit.sha, 0, 7)}</span>
              <span>·</span>
              <span>{relative_time(commit.authored_at)}</span>
            </div>
          </a>
        </div>
      </div>
    </div>
  </div>
</section>
```

**Step 3: Run `mix precommit` to verify everything compiles and passes**

Run: `mix precommit`
Expected: Compiles, tests pass, no warnings

**Step 4: Commit**

```bash
git add lib/greenlight_web/live/dashboard_live.ex
git commit -m "feat: add user insights section to dashboard template"
```

---

### Task 7: Write DashboardLive test for user insights section

**Files:**
- Create: `test/greenlight_web/live/dashboard_live_test.exs`

**Step 1: Write the test file**

Create `test/greenlight_web/live/dashboard_live_test.exs`:

```elixir
defmodule GreenlightWeb.DashboardLiveTest do
  use GreenlightWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      case conn.request_path do
        "/user" ->
          Req.Test.json(conn, %{
            "login" => "testuser",
            "name" => "Test User",
            "avatar_url" => "https://avatars.githubusercontent.com/u/12345"
          })

        "/search/issues" ->
          Req.Test.json(conn, %{
            "items" => [
              %{
                "number" => 42,
                "title" => "Add feature X",
                "state" => "open",
                "html_url" => "https://github.com/owner/repo/pull/42",
                "updated_at" => "2026-02-19T10:00:00Z",
                "repository_url" => "https://api.github.com/repos/owner/repo"
              }
            ]
          })

        "/search/commits" ->
          Req.Test.json(conn, %{
            "items" => [
              %{
                "sha" => "abc1234567890",
                "html_url" => "https://github.com/owner/repo/commit/abc1234567890",
                "commit" => %{
                  "message" => "Fix the thing",
                  "author" => %{"date" => "2026-02-19T09:00:00Z"}
                },
                "repository" => %{"full_name" => "owner/repo"}
              }
            ]
          })

        "/orgs/" <> _ ->
          Req.Test.json(conn, [])
      end
    end)

    :ok
  end

  test "renders user profile bar with username", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    # Wait for async loads
    _ = render_async(view)
    assert has_element?(view, "img[alt='testuser']")
  end

  test "renders recent PRs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    _ = render_async(view)
    html = render(view)
    assert html =~ "Add feature X"
    assert html =~ "#42"
  end

  test "renders recent commits", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    _ = render_async(view)
    html = render(view)
    assert html =~ "Fix the thing"
    assert html =~ "abc1234"
  end
end
```

**Step 2: Run the test**

Run: `mix test test/greenlight_web/live/dashboard_live_test.exs --seed 0`
Expected: PASS. If `render_async` is not available (it's for `assign_async`), remove those lines — the `send(self(), ...)` pattern processes during `live/2` mount. Adjust test accordingly: the data may already be rendered in the initial `render(view)`.

**Step 3: Run full test suite**

Run: `mix precommit`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add test/greenlight_web/live/dashboard_live_test.exs
git commit -m "test: add dashboard live test for user insights section"
```

---

### Task 8: Final verification

**Step 1: Run full precommit checks**

Run: `mix precommit`
Expected: All tests pass, no warnings, code compiles clean

**Step 2: Manual smoke test (if dev server available)**

Run: `mix phx.server` and navigate to `http://localhost:4000`
Expected: Dashboard shows user profile bar at top, followed by recent PRs and commits in two columns, then bookmarked repos, then organizations

**Step 3: Commit any final fixes if needed**
