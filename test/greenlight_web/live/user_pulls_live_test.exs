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
    # Use the link href to check page 1 items are absent (avoids substring match issues)
    refute has_element?(view, "a[href='/repos/owner/repo/pull/10']")
  end

  test "renders pagination controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls")
    html = render(view)

    assert has_element?(view, "#pulls-pagination")
    assert html =~ "Page 1 of 2"
  end

  test "navigates between pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/testuser/pulls")

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
