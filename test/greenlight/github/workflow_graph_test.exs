defmodule Greenlight.GitHub.WorkflowGraphTest do
  use ExUnit.Case, async: true

  alias Greenlight.GitHub.Models
  alias Greenlight.GitHub.WorkflowGraph

  describe "build_workflow_dag/1" do
    test "converts workflow runs to Svelte Flow nodes and edges" do
      runs = [
        %Models.WorkflowRun{
          id: 1,
          name: "CI",
          workflow_id: 10,
          status: :completed,
          conclusion: :success,
          head_sha: "abc",
          event: "push",
          html_url: "https://github.com/o/r/actions/runs/1",
          created_at: ~U[2026-02-12 10:00:00Z],
          updated_at: ~U[2026-02-12 10:05:00Z],
          jobs: [
            %Models.Job{id: 100, name: "build", status: :completed, conclusion: :success},
            %Models.Job{id: 101, name: "test", status: :completed, conclusion: :success}
          ]
        },
        %Models.WorkflowRun{
          id: 2,
          name: "Deploy",
          workflow_id: 20,
          status: :queued,
          conclusion: nil,
          head_sha: "abc",
          event: "workflow_run",
          html_url: "https://github.com/o/r/actions/runs/2",
          created_at: ~U[2026-02-12 10:05:00Z],
          updated_at: ~U[2026-02-12 10:05:00Z],
          jobs: []
        }
      ]

      %{nodes: nodes, edges: edges} = WorkflowGraph.build_workflow_dag(runs)

      assert length(nodes) == 2
      assert Enum.any?(nodes, fn n -> n.id == "wf-1" end)
      assert Enum.any?(nodes, fn n -> n.id == "wf-2" end)

      # workflow_run event creates an edge from CI -> Deploy
      assert length(edges) >= 1
      assert Enum.any?(edges, fn e -> e.source == "wf-1" and e.target == "wf-2" end)
    end
  end

  describe "build_job_dag/1" do
    test "converts jobs to Svelte Flow nodes and edges using needs" do
      jobs = [
        %Models.Job{
          id: 100,
          name: "build",
          status: :completed,
          conclusion: :success,
          html_url: "https://github.com/o/r/actions/runs/1/job/100",
          started_at: ~U[2026-02-12 10:00:00Z],
          completed_at: ~U[2026-02-12 10:02:00Z],
          current_step: nil,
          steps: [],
          needs: []
        },
        %Models.Job{
          id: 101,
          name: "test",
          status: :in_progress,
          conclusion: nil,
          html_url: "https://github.com/o/r/actions/runs/1/job/101",
          started_at: ~U[2026-02-12 10:02:00Z],
          completed_at: nil,
          current_step: "Run tests",
          steps: [
            %Models.Step{name: "Checkout", status: :completed, conclusion: :success, number: 1},
            %Models.Step{name: "Run tests", status: :in_progress, conclusion: nil, number: 2}
          ],
          needs: ["build"]
        },
        %Models.Job{
          id: 102,
          name: "deploy",
          status: :queued,
          conclusion: nil,
          html_url: "https://github.com/o/r/actions/runs/1/job/102",
          started_at: nil,
          completed_at: nil,
          current_step: nil,
          steps: [],
          needs: ["test"]
        }
      ]

      %{nodes: nodes, edges: edges} = WorkflowGraph.build_job_dag(jobs)

      assert length(nodes) == 3
      assert length(edges) == 2

      test_node = Enum.find(nodes, fn n -> n.id == "job-101" end)
      assert test_node.data.current_step == "Run tests"
      assert test_node.data.steps_completed == 1
      assert test_node.data.steps_total == 2
    end
  end
end
