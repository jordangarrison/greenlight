defmodule Greenlight.GitHub.PollerTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Poller

  setup do
    # Stub GitHub API responses
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
                "path" => ".github/workflows/ci.yml",
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
              },
              %{
                "id" => 101,
                "name" => "test",
                "status" => "completed",
                "conclusion" => "success",
                "started_at" => "2026-02-12T10:02:00Z",
                "completed_at" => "2026-02-12T10:04:00Z",
                "html_url" => "https://github.com/owner/repo/actions/runs/1/job/101",
                "steps" => []
              }
            ]
          })

        "/repos/owner/repo/contents/.github/workflows/ci.yml" ->
          yaml_content = """
          name: CI
          on: push
          jobs:
            build:
              runs-on: ubuntu-latest
              steps: []
            test:
              needs: build
              runs-on: ubuntu-latest
              steps: []
          """

          Req.Test.json(conn, %{
            "content" => Base.encode64(yaml_content),
            "encoding" => "base64"
          })
      end
    end)

    :ok
  end

  test "poller fetches data and broadcasts via PubSub" do
    Phoenix.PubSub.subscribe(Greenlight.PubSub, "pipeline:owner/repo:abc123")

    # Start without initial poll so we can set up Req.Test.allow first
    {:ok, pid} =
      Poller.start_link(
        owner: "owner",
        repo: "repo",
        ref: "abc123",
        poll_interval: 100,
        skip_initial_poll: true
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    # Allow the poller process to use our Req.Test stub
    Req.Test.allow(Greenlight.GitHub.Client, self(), pid)

    # Trigger polling manually
    send(pid, :poll)

    # Should receive a broadcast with pipeline data including workflow_runs
    assert_receive {:pipeline_update,
                    %{nodes: nodes, edges: _edges, workflow_runs: workflow_runs}},
                   5_000

    assert length(nodes) > 0

    # Verify needs were resolved from the workflow YAML
    [wf_run] = workflow_runs
    test_job = Enum.find(wf_run.jobs, &(&1.name == "test"))
    assert test_job.needs == ["build"]

    build_job = Enum.find(wf_run.jobs, &(&1.name == "build"))
    assert build_job.needs == []
  end
end
