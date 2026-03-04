defmodule Greenlight.GitHub.DomainTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub

  setup do
    Req.Test.stub(Greenlight.GitHub.Client, fn conn ->
      route(conn)
    end)

    :ok
  end

  # Route: /repos/owner/repo/actions/runs
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

  # Route: /repos/owner/repo/actions/runs/123/jobs
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

  # Route: /repos/owner/repo/pulls
  defp route(%Plug.Conn{request_path: "/repos/owner/repo/pulls"} = conn) do
    Req.Test.json(conn, [
      %{"number" => 42, "title" => "Fix bug", "head" => %{"sha" => "def456"}}
    ])
  end

  # Route: /repos/owner/repo/branches
  defp route(%Plug.Conn{request_path: "/repos/owner/repo/branches"} = conn) do
    Req.Test.json(conn, [
      %{"name" => "main", "commit" => %{"sha" => "abc123"}}
    ])
  end

  # Route: /repos/owner/repo/releases
  defp route(%Plug.Conn{request_path: "/repos/owner/repo/releases"} = conn) do
    Req.Test.json(conn, [
      %{"tag_name" => "v1.0.0", "name" => "Release 1.0"}
    ])
  end

  # Route: /orgs/myorg/repos
  defp route(%Plug.Conn{request_path: "/orgs/myorg/repos"} = conn) do
    Req.Test.json(conn, [
      %{"full_name" => "myorg/repo1"},
      %{"full_name" => "myorg/repo2"}
    ])
  end

  # Route: /user
  defp route(%Plug.Conn{request_path: "/user"} = conn) do
    Req.Test.json(conn, %{
      "login" => "testuser",
      "name" => "Test User",
      "avatar_url" => "https://avatars.githubusercontent.com/u/123"
    })
  end

  # Route: /search/issues
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

  # Route: /search/commits
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
      assert run.conclusion == nil
      assert run.owner == "owner"
      assert run.repo == "repo"
      assert run.head_sha == "abc123"
      assert run.event == "push"
      assert run.path == ".github/workflows/ci.yml"
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
      assert job.repo == "repo"
      assert job.run_id == 123

      assert [%Greenlight.GitHub.Step{} = step] = job.steps
      assert step.name == "Checkout"
      assert step.status == :completed
      assert step.conclusion == :success
      assert step.number == 1
    end
  end

  describe "list_pulls!/2" do
    test "returns Pull resources" do
      pulls = GitHub.list_pulls!("owner", "repo")

      assert [%Greenlight.GitHub.Pull{} = pull] = pulls
      assert pull.number == 42
      assert pull.title == "Fix bug"
      assert pull.head_sha == "def456"
    end
  end

  describe "list_branches!/2" do
    test "returns Branch resources" do
      branches = GitHub.list_branches!("owner", "repo")

      assert [%Greenlight.GitHub.Branch{} = branch] = branches
      assert branch.name == "main"
      assert branch.sha == "abc123"
    end
  end

  describe "list_releases!/2" do
    test "returns Release resources" do
      releases = GitHub.list_releases!("owner", "repo")

      assert [%Greenlight.GitHub.Release{} = release] = releases
      assert release.tag_name == "v1.0.0"
      assert release.name == "Release 1.0"
    end
  end

  describe "list_org_repos!/1" do
    test "returns Repository resources" do
      repos = GitHub.list_org_repos!("myorg")

      assert [
               %Greenlight.GitHub.Repository{full_name: "myorg/repo1"} = repo1,
               %Greenlight.GitHub.Repository{full_name: "myorg/repo2"} = repo2
             ] = repos

      assert repo1.name == "repo1"
      assert repo1.owner == "myorg"
      assert repo2.name == "repo2"
      assert repo2.owner == "myorg"
    end
  end

  describe "get_authenticated_user!/0" do
    test "returns User resources" do
      users = GitHub.get_authenticated_user!()

      assert [%Greenlight.GitHub.User{} = user] = users
      assert user.login == "testuser"
      assert user.name == "Test User"
      assert user.avatar_url == "https://avatars.githubusercontent.com/u/123"
    end
  end

  describe "list_user_prs!/1" do
    test "returns UserPR resources" do
      prs = GitHub.list_user_prs!("testuser")

      assert [%Greenlight.GitHub.UserPR{} = pr] = prs
      assert pr.number == 10
      assert pr.title == "My PR"
      assert pr.state == "open"
      assert pr.html_url == "https://github.com/org/repo/pull/10"
      assert pr.repo == "org/repo"
      assert pr.updated_at == "2026-02-12T10:00:00Z"
    end
  end

  describe "list_user_commits!/1" do
    test "returns UserCommit resources" do
      commits = GitHub.list_user_commits!("testuser")

      assert [%Greenlight.GitHub.UserCommit{} = commit] = commits
      assert commit.sha == "abc123"
      assert commit.message == "fix: something"
      assert commit.repo == "org/repo"
      assert commit.html_url == "https://github.com/org/repo/commit/abc123"
      assert commit.authored_at == "2026-02-12T10:00:00Z"
    end
  end
end
