# PR and Commit Full Views Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add paginated full-view pages for user PRs and commits at `/:username/pulls` and `/:username/commits`, accessible via "View all" links on the dashboard.

**Architecture:** Extend the GitHub Client and Ash actions to support an optional `per_page` parameter. Increase `UserInsightsServer` cache from 5 to 50 items. Add two new LiveViews that read from cache and paginate client-side (10 per page). Dashboard shows first 5 items with "View all" links.

**Tech Stack:** Elixir, Phoenix LiveView, Ash Framework 3.x, Tailwind CSS

---

### Task 1: Add optional `per_page` to GitHub Client functions

**Files:**
- Modify: `lib/greenlight/github/client.ex:143-205`

**Step 1: Modify `search_user_prs/1` to accept opts**

Change the function signature and use `per_page` from opts:

```elixir
def search_user_prs(username, opts \\ %{}) do
  per_page = Map.get(opts, :per_page, 50)

  case Req.get(new(),
         url: "/search/issues",
         params: %{q: "author:#{username} type:pr sort:updated", per_page: per_page}
       ) do
```

The rest of the function body stays the same.

**Step 2: Modify `search_user_commits/1` to accept opts**

Same pattern:

```elixir
def search_user_commits(username, opts \\ %{}) do
  per_page = Map.get(opts, :per_page, 50)

  case Req.get(new(),
         url: "/search/commits",
         params: %{q: "author:#{username} sort:author-date", per_page: per_page}
       ) do
```

**Step 3: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: SUCCESS

**Step 4: Commit**

```
feat: add optional per_page param to GitHub client search functions
```

---

### Task 2: Add optional `per_page` argument to Ash resources and actions

**Files:**
- Modify: `lib/greenlight/github/user_pr.ex:18-24`
- Modify: `lib/greenlight/github/user_commit.ex:17-23`
- Modify: `lib/greenlight/github/actions/list_user_prs.ex:7-10`
- Modify: `lib/greenlight/github/actions/list_user_commits.ex:7-10`

**Step 1: Add `per_page` argument to UserPR resource**

In `lib/greenlight/github/user_pr.ex`, add the argument inside the `read :list` block:

```elixir
actions do
  read :list do
    argument(:username, :string, allow_nil?: false)
    argument(:per_page, :integer)

    manual(Greenlight.GitHub.Actions.ListUserPRs)
  end
end
```

**Step 2: Add `per_page` argument to UserCommit resource**

Same change in `lib/greenlight/github/user_commit.ex`:

```elixir
actions do
  read :list do
    argument(:username, :string, allow_nil?: false)
    argument(:per_page, :integer)

    manual(Greenlight.GitHub.Actions.ListUserCommits)
  end
end
```

**Step 3: Update ListUserPRs action to pass optional args**

In `lib/greenlight/github/actions/list_user_prs.ex`, extract `per_page` from query arguments and pass to client. Follow the pattern from `ListWorkflowRuns`:

```elixir
def read(query, _data_layer_query, _opts, _context) do
  username = query.arguments.username

  opts =
    [:per_page]
    |> Enum.map(fn key -> {key, Map.get(query.arguments, key)} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

  case Client.search_user_prs(username, opts) do
```

**Step 4: Update ListUserCommits action the same way**

In `lib/greenlight/github/actions/list_user_commits.ex`:

```elixir
def read(query, _data_layer_query, _opts, _context) do
  username = query.arguments.username

  opts =
    [:per_page]
    |> Enum.map(fn key -> {key, Map.get(query.arguments, key)} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

  case Client.search_user_commits(username, opts) do
```

**Step 5: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: SUCCESS

**Step 6: Commit**

```
feat: add optional per_page argument to Ash UserPR and UserCommit actions
```

---

### Task 3: Update UserInsightsServer to fetch 50 items

**Files:**
- Modify: `lib/greenlight/github/user_insights_server.ex:66-89`

**Step 1: Pass `per_page: 50` to domain calls**

In `fetch_user_insights/0`, update the Task.async calls to pass the per_page option:

```elixir
defp fetch_user_insights do
  case Greenlight.GitHub.get_authenticated_user() do
    {:ok, [user | _]} ->
      prs_task = Task.async(fn -> Greenlight.GitHub.list_user_prs(user.login, %{per_page: 50}) end)
      commits_task = Task.async(fn -> Greenlight.GitHub.list_user_commits(user.login, %{per_page: 50}) end)
```

The rest of the function stays the same.

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: SUCCESS

**Step 3: Commit**

```
feat: increase UserInsightsServer cache to 50 PRs and commits
```

---

### Task 4: Update dashboard to show first 5 items and "View all" links

**Files:**
- Modify: `lib/greenlight_web/live/dashboard_live.ex:128-194`

**Step 1: Add "View all" links and limit to 5 items**

Update the PRs section header (around line 129) to include a "View all" link:

```heex
<div class="flex items-center justify-between mb-3">
  <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] flex items-center gap-2">
    <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Pull Requests
  </h3>
  <.link
    navigate={"/#{@user.login}/pulls"}
    class="text-xs text-[var(--gl-text-muted)] hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
  >
    View all &rarr;
  </.link>
</div>
```

Change the `:for` on the PR cards to slice to 5:

```heex
<.link
  :for={pr <- Enum.take(@user_prs, 5)}
```

Update the Commits section header the same way (around line 169):

```heex
<div class="flex items-center justify-between mb-3">
  <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] flex items-center gap-2">
    <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Commits
  </h3>
  <.link
    navigate={"/#{@user.login}/commits"}
    class="text-xs text-[var(--gl-text-muted)] hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
  >
    View all &rarr;
  </.link>
</div>
```

Change the `:for` on commit cards:

```heex
<.link
  :for={commit <- Enum.take(@user_commits, 5)}
```

**Step 2: Run existing tests**

Run: `mix test test/greenlight_web/live/dashboard_live_test.exs`
Expected: All 4 tests PASS (existing behavior preserved)

**Step 3: Commit**

```
feat: add "View all" links to dashboard PR and commit sections
```

---

### Task 5: Create UserPullsLive

**Files:**
- Create: `lib/greenlight_web/live/user_pulls_live.ex`

**Step 1: Write the test file**

Create `test/greenlight_web/live/user_pulls_live_test.exs`:

```elixir
defmodule GreenlightWeb.UserPullsLiveTest do
  use GreenlightWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Greenlight.Cache

  @prs Enum.map(1..15, fn i ->
    %{
      number: i,
      title: "PR number #{i}",
      state: "open",
      html_url: "https://github.com/owner/repo/pull/#{i}",
      updated_at: "2026-03-0#{min(i, 9)}T10:00:00Z",
      repo: "owner/repo"
    }
  end)

  setup do
    Cache.init()

    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      Req.Test.json(conn, %{})
    end)

    Cache.put(:user_insights, %{
      user: %{login: "testuser", name: "Test User", avatar_url: "https://example.com/avatar.png"},
      prs: @prs,
      commits: [],
      loading: false
    })

    :ok
  end

  test "renders first page of PRs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls")
    html = render(view)

    assert html =~ "PR number 1"
    assert html =~ "PR number 10"
    refute html =~ "PR number 11"
  end

  test "renders second page of PRs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls?page=2")
    html = render(view)

    assert html =~ "PR number 11"
    assert html =~ "PR number 15"
    refute html =~ "PR number 1"
  end

  test "renders pagination controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls")
    html = render(view)

    assert has_element?(view, "#pulls-pagination")
    assert html =~ "Page 1 of 2"
  end

  test "navigates between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls")

    html =
      view
      |> element("#pulls-next")
      |> render_click()

    assert_patched(view, "/testuser/pulls?page=2")
  end

  test "shows page title with username", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/testuser/pulls")
    assert html =~ "testuser"
    assert html =~ "Pull Requests"
  end
end
```

**Step 2: Run the test to see it fail**

Run: `mix test test/greenlight_web/live/user_pulls_live_test.exs`
Expected: FAIL (module does not exist, route not defined)

**Step 3: Create the LiveView module**

Create `lib/greenlight_web/live/user_pulls_live.ex`:

```elixir
defmodule GreenlightWeb.UserPullsLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.UserInsightsServer
  import Greenlight.TimeHelpers, only: [relative_time: 1]

  @page_size 10

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    cached = UserInsightsServer.get_cached()

    if connected?(socket), do: UserInsightsServer.subscribe()

    {:ok,
     assign(socket,
       page_title: "#{username} · Pull Requests",
       username: username,
       all_prs: cached.prs
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    all_prs = socket.assigns.all_prs
    total = length(all_prs)
    total_pages = max(ceil(total / @page_size), 1)
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1) |> min(total_pages)
    items = Enum.slice(all_prs, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       page: page,
       total_pages: total_pages,
       prs: items
     )}
  end

  @impl true
  def handle_info({:user_insights_update, data}, socket) do
    all_prs = data.prs
    total = length(all_prs)
    total_pages = max(ceil(total / @page_size), 1)
    page = min(socket.assigns.page, total_pages)
    items = Enum.slice(all_prs, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       all_prs: all_prs,
       page: page,
       total_pages: total_pages,
       prs: items
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center gap-3 mb-8">
          <.link navigate="/" class="text-[var(--gl-text-muted)] hover:text-white transition-colors">
            <.icon name="hero-arrow-left" class="w-5 h-5" />
          </.link>
          <h1 class="text-3xl font-bold uppercase tracking-wider text-white">
            Pull Requests
          </h1>
          <span class="text-lg text-[var(--gl-text-muted)]">
            · {@username}
          </span>
        </div>

        <div :if={@prs == []} class="nb-card p-8 text-center">
          <p class="text-[var(--gl-text-muted)]">No pull requests found</p>
        </div>

        <div class="space-y-2">
          <.link
            :for={pr <- @prs}
            navigate={"/repos/#{pr.repo}/pull/#{pr.number}"}
            class="nb-card-muted block p-4 group"
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
          </.link>
        </div>

        <div :if={@total_pages > 1} id="pulls-pagination" class="flex items-center justify-center gap-4 mt-8">
          <.link
            :if={@page > 1}
            patch={"/#{@username}/pulls?page=#{@page - 1}"}
            id="pulls-prev"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            &larr; Previous
          </.link>
          <span class="text-sm text-[var(--gl-text-muted)]">
            Page {@page} of {@total_pages}
          </span>
          <.link
            :if={@page < @total_pages}
            patch={"/#{@username}/pulls?page=#{@page + 1}"}
            id="pulls-next"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            Next &rarr;
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 4: Add route to router**

In `lib/greenlight_web/router.ex`, add inside the `scope "/", GreenlightWeb` block after line 25:

```elixir
live "/:username/pulls", UserPullsLive
```

**Step 5: Run the tests**

Run: `mix test test/greenlight_web/live/user_pulls_live_test.exs`
Expected: All 5 tests PASS

**Step 6: Commit**

```
feat: add UserPullsLive with paginated full view
```

---

### Task 6: Create UserCommitsLive

**Files:**
- Create: `lib/greenlight_web/live/user_commits_live.ex`

**Step 1: Write the test file**

Create `test/greenlight_web/live/user_commits_live_test.exs`:

```elixir
defmodule GreenlightWeb.UserCommitsLiveTest do
  use GreenlightWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Greenlight.Cache

  @commits Enum.map(1..15, fn i ->
    %{
      sha: "abc#{String.pad_leading(Integer.to_string(i), 10, "0")}",
      message: "Commit message #{i}",
      repo: "owner/repo",
      html_url: "https://github.com/owner/repo/commit/abc#{String.pad_leading(Integer.to_string(i), 10, "0")}",
      authored_at: "2026-03-0#{min(i, 9)}T10:00:00Z"
    }
  end)

  setup do
    Cache.init()

    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      Req.Test.json(conn, %{})
    end)

    Cache.put(:user_insights, %{
      user: %{login: "testuser", name: "Test User", avatar_url: "https://example.com/avatar.png"},
      prs: [],
      commits: @commits,
      loading: false
    })

    :ok
  end

  test "renders first page of commits", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits")
    html = render(view)

    assert html =~ "Commit message 1"
    assert html =~ "Commit message 10"
    refute html =~ "Commit message 11"
  end

  test "renders second page of commits", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits?page=2")
    html = render(view)

    assert html =~ "Commit message 11"
    assert html =~ "Commit message 15"
    refute html =~ "Commit message 1"
  end

  test "renders pagination controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits")
    html = render(view)

    assert has_element?(view, "#commits-pagination")
    assert html =~ "Page 1 of 2"
  end

  test "navigates between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits")

    html =
      view
      |> element("#commits-next")
      |> render_click()

    assert_patched(view, "/testuser/commits?page=2")
  end

  test "shows page title with username", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/testuser/commits")
    assert html =~ "testuser"
    assert html =~ "Commits"
  end
end
```

**Step 2: Run the test to see it fail**

Run: `mix test test/greenlight_web/live/user_commits_live_test.exs`
Expected: FAIL (module does not exist, route not defined)

**Step 3: Create the LiveView module**

Create `lib/greenlight_web/live/user_commits_live.ex`:

```elixir
defmodule GreenlightWeb.UserCommitsLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.UserInsightsServer
  import Greenlight.TimeHelpers, only: [relative_time: 1]

  @page_size 10

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    cached = UserInsightsServer.get_cached()

    if connected?(socket), do: UserInsightsServer.subscribe()

    {:ok,
     assign(socket,
       page_title: "#{username} · Commits",
       username: username,
       all_commits: cached.commits
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    all_commits = socket.assigns.all_commits
    total = length(all_commits)
    total_pages = max(ceil(total / @page_size), 1)
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1) |> min(total_pages)
    items = Enum.slice(all_commits, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       page: page,
       total_pages: total_pages,
       commits: items
     )}
  end

  @impl true
  def handle_info({:user_insights_update, data}, socket) do
    all_commits = data.commits
    total = length(all_commits)
    total_pages = max(ceil(total / @page_size), 1)
    page = min(socket.assigns.page, total_pages)
    items = Enum.slice(all_commits, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       all_commits: all_commits,
       page: page,
       total_pages: total_pages,
       commits: items
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center gap-3 mb-8">
          <.link navigate="/" class="text-[var(--gl-text-muted)] hover:text-white transition-colors">
            <.icon name="hero-arrow-left" class="w-5 h-5" />
          </.link>
          <h1 class="text-3xl font-bold uppercase tracking-wider text-white">
            Commits
          </h1>
          <span class="text-lg text-[var(--gl-text-muted)]">
            · {@username}
          </span>
        </div>

        <div :if={@commits == []} class="nb-card p-8 text-center">
          <p class="text-[var(--gl-text-muted)]">No commits found</p>
        </div>

        <div class="space-y-2">
          <.link
            :for={commit <- @commits}
            navigate={"/repos/#{commit.repo}/commit/#{commit.sha}"}
            class="nb-card-muted block p-4 group"
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
          </.link>
        </div>

        <div :if={@total_pages > 1} id="commits-pagination" class="flex items-center justify-center gap-4 mt-8">
          <.link
            :if={@page > 1}
            patch={"/#{@username}/commits?page=#{@page - 1}"}
            id="commits-prev"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            &larr; Previous
          </.link>
          <span class="text-sm text-[var(--gl-text-muted)]">
            Page {@page} of {@total_pages}
          </span>
          <.link
            :if={@page < @total_pages}
            patch={"/#{@username}/commits?page=#{@page + 1}"}
            id="commits-next"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            Next &rarr;
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 4: Add route to router**

In `lib/greenlight_web/router.ex`, add after the pulls route:

```elixir
live "/:username/commits", UserCommitsLive
```

**Step 5: Run the tests**

Run: `mix test test/greenlight_web/live/user_commits_live_test.exs`
Expected: All 5 tests PASS

**Step 6: Commit**

```
feat: add UserCommitsLive with paginated full view
```

---

### Task 7: Run full test suite and verify

**Step 1: Run all tests**

Run: `mix test`
Expected: All tests PASS

**Step 2: Run precommit checks**

Run: `mix precommit`
Expected: SUCCESS (compile + format + credo + tests)

**Step 3: Fix any issues found**

If any tests fail or warnings appear, fix them.

**Step 4: Final commit if any fixes were needed**

```
fix: address precommit issues
```
