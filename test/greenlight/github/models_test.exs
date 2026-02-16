defmodule Greenlight.GitHub.ModelsTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Models

  describe "WorkflowRun.from_api/1" do
    test "parses a GitHub API workflow run response" do
      api_response = %{
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

      run = Models.WorkflowRun.from_api(api_response)

      assert run.id == 123
      assert run.name == "CI"
      assert run.status == :in_progress
      assert run.conclusion == nil
      assert run.head_sha == "abc123"
      assert run.event == "push"
      assert run.html_url == "https://github.com/owner/repo/actions/runs/123"
      assert run.path == ".github/workflows/ci.yml"
      assert run.jobs == []
    end
  end

  describe "Job.from_api/1" do
    test "parses a GitHub API job response" do
      api_response = %{
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
          },
          %{
            "name" => "Run tests",
            "status" => "completed",
            "conclusion" => "success",
            "number" => 2,
            "started_at" => "2026-02-12T10:00:10Z",
            "completed_at" => "2026-02-12T10:02:30Z"
          }
        ]
      }

      job = Models.Job.from_api(api_response)

      assert job.id == 789
      assert job.name == "build"
      assert job.status == :completed
      assert job.conclusion == :success
      assert length(job.steps) == 2
      assert job.current_step == nil
    end

    test "identifies the current step for an in-progress job" do
      api_response = %{
        "id" => 789,
        "name" => "build",
        "status" => "in_progress",
        "conclusion" => nil,
        "started_at" => "2026-02-12T10:00:00Z",
        "completed_at" => nil,
        "html_url" => "https://github.com/owner/repo/actions/runs/123/job/789",
        "steps" => [
          %{
            "name" => "Checkout",
            "status" => "completed",
            "conclusion" => "success",
            "number" => 1,
            "started_at" => "2026-02-12T10:00:00Z",
            "completed_at" => "2026-02-12T10:00:10Z"
          },
          %{
            "name" => "Run tests",
            "status" => "in_progress",
            "conclusion" => nil,
            "number" => 2,
            "started_at" => "2026-02-12T10:00:10Z",
            "completed_at" => nil
          }
        ]
      }

      job = Models.Job.from_api(api_response)

      assert job.current_step == "Run tests"
    end
  end
end
