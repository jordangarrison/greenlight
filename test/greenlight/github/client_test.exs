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

        "/repos/owner/repo/contents/.github/workflows/ci.yml" ->
          yaml_content = "name: CI\non:\n  push:\njobs:\n  build:\n    runs-on: ubuntu-latest\n"
          encoded = Base.encode64(yaml_content)

          Req.Test.json(conn, %{
            "content" => encoded,
            "encoding" => "base64"
          })

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

  test "get_authenticated_user/0 returns user profile" do
    {:ok, user} = Client.get_authenticated_user()
    assert user.login == "testuser"
    assert user.name == "Test User"
    assert user.avatar_url == "https://avatars.githubusercontent.com/u/12345"
  end

  test "get_repo_content/4 returns decoded file content" do
    {:ok, content} =
      Client.get_repo_content("owner", "repo", ".github/workflows/ci.yml", "abc123")

    assert content =~ "name: CI"
    assert content =~ "jobs:"
  end

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

  test "search_user_commits/1 returns recent commits for user" do
    {:ok, commits} = Client.search_user_commits("testuser")
    assert [commit] = commits
    assert commit.sha == "abc1234567890"
    assert commit.message == "Fix the thing"
    assert commit.repo == "owner/repo"
    assert commit.html_url == "https://github.com/owner/repo/commit/abc1234567890"
    assert commit.authored_at == "2026-02-19T09:00:00Z"
  end
end
