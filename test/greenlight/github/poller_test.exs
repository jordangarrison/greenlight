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
                "id" => 1, "name" => "CI", "workflow_id" => 10,
                "status" => "completed", "conclusion" => "success",
                "head_sha" => "abc123", "event" => "push",
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
                "id" => 100, "name" => "build",
                "status" => "completed", "conclusion" => "success",
                "started_at" => "2026-02-12T10:00:00Z",
                "completed_at" => "2026-02-12T10:02:00Z",
                "html_url" => "https://github.com/owner/repo/actions/runs/1/job/100",
                "steps" => []
              }
            ]
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
        owner: "owner", repo: "repo", ref: "abc123",
        poll_interval: 100, skip_initial_poll: true
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    # Allow the poller process to use our Req.Test stub
    Req.Test.allow(Greenlight.GitHub.Client, self(), pid)

    # Trigger polling manually
    send(pid, :poll)

    # Should receive a broadcast with pipeline data
    assert_receive {:pipeline_update, %{nodes: nodes, edges: _edges}}, 5_000
    assert length(nodes) > 0
  end
end
