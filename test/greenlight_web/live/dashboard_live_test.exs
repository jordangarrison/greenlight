defmodule GreenlightWeb.DashboardLiveTest do
  use GreenlightWeb.ConnCase, async: false
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

  # Mount the LiveView and wait for all async data to load.
  # The mount sends :load_org_repos and :load_user, then :load_user sends
  # :load_user_activity. We need two sync points to ensure all chained
  # messages are processed before rendering.
  defp mount_and_wait(conn) do
    {:ok, view, _html} = live(conn, "/")
    # First sync: waits for :load_org_repos and :load_user to complete.
    # :load_user sends :load_user_activity to self, which is now queued.
    _ = :sys.get_state(view.pid)
    # Second sync: waits for :load_user_activity to complete.
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
end
