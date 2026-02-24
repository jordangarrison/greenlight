defmodule GreenlightWeb.DashboardLiveTest do
  use GreenlightWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Greenlight.Cache

  setup do
    # Ensure the cache table exists for tests
    Cache.init()

    # Stub org repos endpoint for dashboard mount
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      case conn.request_path do
        "/orgs/" <> _ ->
          Req.Test.json(conn, [])

        _ ->
          Req.Test.json(conn, %{})
      end
    end)

    # Seed the cache with user insights data so the dashboard renders instantly
    Cache.put(:user_insights, %{
      user: %{
        login: "testuser",
        name: "Test User",
        avatar_url: "https://avatars.githubusercontent.com/u/12345"
      },
      prs: [
        %{
          number: 42,
          title: "Add feature X",
          state: "open",
          html_url: "https://github.com/owner/repo/pull/42",
          updated_at: "2026-02-19T10:00:00Z",
          repo: "owner/repo"
        }
      ],
      commits: [
        %{
          sha: "abc1234567890",
          html_url: "https://github.com/owner/repo/commit/abc1234567890",
          message: "Fix the thing",
          authored_at: "2026-02-19T09:00:00Z",
          repo: "owner/repo"
        }
      ],
      loading: false
    })

    :ok
  end

  defp mount_and_wait(conn) do
    {:ok, view, _html} = live(conn, "/")
    # Sync: wait for :load_org_repos to complete
    _ = :sys.get_state(view.pid)
    {view, render(view)}
  end

  test "renders user profile bar with username", %{conn: conn} do
    {_view, html} = mount_and_wait(conn)
    assert html =~ "testuser"
  end

  test "renders recent PRs", %{conn: conn} do
    {_view, html} = mount_and_wait(conn)
    assert html =~ "Add feature X"
    assert html =~ "#42"
  end

  test "renders recent commits", %{conn: conn} do
    {_view, html} = mount_and_wait(conn)
    assert html =~ "Fix the thing"
    assert html =~ "abc1234"
  end

  test "updates when receiving user_insights_update broadcast", %{conn: conn} do
    {view, _html} = mount_and_wait(conn)

    send(view.pid, {:user_insights_update, %{
      user: %{login: "newuser", name: "New User", avatar_url: "https://example.com/avatar.png"},
      prs: [],
      commits: [],
      loading: false
    }})

    html = render(view)
    assert html =~ "newuser"
    refute html =~ "testuser"
  end
end
