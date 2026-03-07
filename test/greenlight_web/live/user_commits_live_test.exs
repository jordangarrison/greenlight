defmodule GreenlightWeb.UserCommitsLiveTest do
  use GreenlightWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Greenlight.Cache

  @commits Enum.map(1..15, fn i ->
             %{
               sha: "abc#{String.pad_leading(Integer.to_string(i), 10, "0")}",
               message: "Commit message #{i}",
               repo: "owner/repo",
               html_url:
                 "https://github.com/owner/repo/commit/abc#{String.pad_leading(Integer.to_string(i), 10, "0")}",
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
    # Use link href to avoid substring match (e.g. "Commit message 1" matches "Commit message 10")
    refute has_element?(view, "a[href='/repos/owner/repo/commit/abc0000000001']")
  end

  test "renders pagination controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits")
    html = render(view)

    assert has_element?(view, "#commits-pagination")
    assert html =~ "Page 1 of 2"
  end

  test "navigates between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/commits")

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
