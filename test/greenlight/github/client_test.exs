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

  test "get_repo_content/4 returns decoded file content" do
    {:ok, content} =
      Client.get_repo_content("owner", "repo", ".github/workflows/ci.yml", "abc123")

    assert content =~ "name: CI"
    assert content =~ "jobs:"
  end
end
