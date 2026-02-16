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

  describe "resolve_job_needs/2" do
    test "populates needs from workflow YAML" do
      yaml = """
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
        deploy:
          needs: [build, test]
          runs-on: ubuntu-latest
          steps: []
      """

      jobs = [
        %Models.Job{id: 1, name: "build", status: :completed, needs: []},
        %Models.Job{id: 2, name: "test", status: :completed, needs: []},
        %Models.Job{id: 3, name: "deploy", status: :queued, needs: []}
      ]

      resolved = WorkflowGraph.resolve_job_needs(yaml, jobs)

      build = Enum.find(resolved, &(&1.name == "build"))
      test_job = Enum.find(resolved, &(&1.name == "test"))
      deploy = Enum.find(resolved, &(&1.name == "deploy"))

      assert build.needs == []
      assert test_job.needs == ["build"]
      assert Enum.sort(deploy.needs) == ["build", "test"]
    end

    test "handles jobs with custom display names" do
      yaml = """
      name: CI
      on: push
      jobs:
        build_step:
          name: Build
          runs-on: ubuntu-latest
          steps: []
        test_step:
          name: Test
          needs: build_step
          runs-on: ubuntu-latest
          steps: []
      """

      jobs = [
        %Models.Job{id: 1, name: "Build", status: :completed, needs: []},
        %Models.Job{id: 2, name: "Test", status: :completed, needs: []}
      ]

      resolved = WorkflowGraph.resolve_job_needs(yaml, jobs)

      build = Enum.find(resolved, &(&1.name == "Build"))
      test_job = Enum.find(resolved, &(&1.name == "Test"))

      assert build.needs == []
      assert test_job.needs == ["Build"]
    end

    test "handles matrix jobs with prefix matching" do
      yaml = """
      name: CI
      on: push
      jobs:
        build:
          runs-on: ubuntu-latest
          steps: []
        test:
          needs: build
          runs-on: ubuntu-latest
          strategy:
            matrix:
              os: [ubuntu, macos]
          steps: []
      """

      jobs = [
        %Models.Job{id: 1, name: "build", status: :completed, needs: []},
        %Models.Job{id: 2, name: "test (ubuntu)", status: :completed, needs: []},
        %Models.Job{id: 3, name: "test (macos)", status: :completed, needs: []}
      ]

      resolved = WorkflowGraph.resolve_job_needs(yaml, jobs)

      ubuntu = Enum.find(resolved, &(&1.name == "test (ubuntu)"))
      macos = Enum.find(resolved, &(&1.name == "test (macos)"))

      assert ubuntu.needs == ["build"]
      assert macos.needs == ["build"]
    end

    test "returns jobs unchanged on invalid YAML" do
      jobs = [%Models.Job{id: 1, name: "build", status: :completed, needs: []}]
      resolved = WorkflowGraph.resolve_job_needs("{{invalid yaml", jobs)
      assert resolved == jobs
    end

    test "returns jobs unchanged when YAML has no jobs key" do
      yaml = """
      name: CI
      on: push
      """

      jobs = [%Models.Job{id: 1, name: "build", status: :completed, needs: []}]
      resolved = WorkflowGraph.resolve_job_needs(yaml, jobs)

      assert Enum.find(resolved, &(&1.name == "build")).needs == []
    end
  end

  describe "serialize_workflow_runs/1" do
    test "serializes workflow runs with job data for client" do
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
            %Models.Job{
              id: 100,
              name: "build",
              status: :completed,
              conclusion: :success,
              html_url: "https://github.com/o/r/actions/runs/1/job/100",
              started_at: ~U[2026-02-12 10:00:00Z],
              completed_at: ~U[2026-02-12 10:02:00Z],
              steps: [],
              needs: []
            },
            %Models.Job{
              id: 101,
              name: "test",
              status: :completed,
              conclusion: :success,
              html_url: "https://github.com/o/r/actions/runs/1/job/101",
              started_at: ~U[2026-02-12 10:02:00Z],
              completed_at: ~U[2026-02-12 10:04:00Z],
              steps: [
                %Models.Step{
                  name: "Checkout",
                  status: :completed,
                  conclusion: :success,
                  number: 1
                }
              ],
              needs: ["build"]
            }
          ]
        }
      ]

      [serialized] = WorkflowGraph.serialize_workflow_runs(runs)

      assert serialized.id == 1
      assert length(serialized.jobs) == 2

      test_job = Enum.find(serialized.jobs, &(&1.name == "test"))
      assert test_job.needs == ["build"]
      assert test_job.steps_completed == 1
      assert test_job.steps_total == 1
      assert test_job.status == "completed"
    end
  end
end
