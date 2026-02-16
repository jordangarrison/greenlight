defmodule Greenlight.GitHub.WorkflowGraph do
  @moduledoc """
  Transforms GitHub Actions data into Svelte Flow node/edge format.
  """

  alias Greenlight.GitHub.Models

  def build_workflow_dag(workflow_runs) do
    nodes = Enum.map(workflow_runs, &workflow_to_node/1)

    # Build edges: workflow_run-triggered workflows depend on earlier workflows
    # with the same SHA
    non_workflow_run = Enum.reject(workflow_runs, &(&1.event == "workflow_run"))
    workflow_run_triggered = Enum.filter(workflow_runs, &(&1.event == "workflow_run"))

    edges =
      for target <- workflow_run_triggered,
          source <- non_workflow_run,
          source.head_sha == target.head_sha do
        %{
          id: "e-#{source.id}-#{target.id}",
          source: "wf-#{source.id}",
          target: "wf-#{target.id}",
          animated: target.status == :in_progress
        }
      end

    %{nodes: nodes, edges: edges}
  end

  def build_job_dag(jobs) do
    # Build a name -> id lookup for resolving `needs`
    name_to_id = Map.new(jobs, fn job -> {job.name, "job-#{job.id}"} end)

    nodes = Enum.map(jobs, &job_to_node/1)

    edges =
      for job <- jobs,
          needed_name <- job.needs || [],
          source_id = Map.get(name_to_id, needed_name),
          source_id != nil do
        %{
          id: "e-#{source_id}-job-#{job.id}",
          source: source_id,
          target: "job-#{job.id}",
          animated: job.status == :in_progress
        }
      end

    %{nodes: nodes, edges: edges}
  end

  defp workflow_to_node(%Models.WorkflowRun{} = run) do
    jobs_passed = Enum.count(run.jobs, &(&1.conclusion == :success))
    jobs_total = length(run.jobs)

    elapsed =
      if run.updated_at && run.created_at do
        DateTime.diff(run.updated_at, run.created_at, :second)
      else
        0
      end

    %{
      id: "wf-#{run.id}",
      type: "workflow",
      position: %{x: 0, y: 0},
      data: %{
        name: run.name,
        status: to_string(run.status),
        conclusion: run.conclusion && to_string(run.conclusion),
        elapsed: elapsed,
        jobs_passed: jobs_passed,
        jobs_total: jobs_total,
        html_url: run.html_url
      }
    }
  end

  defp job_to_node(%Models.Job{} = job) do
    steps_completed = Enum.count(job.steps, &(&1.status == :completed))
    steps_total = length(job.steps)

    elapsed =
      if job.started_at do
        end_time = job.completed_at || DateTime.utc_now()
        DateTime.diff(end_time, job.started_at, :second)
      else
        0
      end

    %{
      id: "job-#{job.id}",
      type: "job",
      position: %{x: 0, y: 0},
      data: %{
        name: job.name,
        status: to_string(job.status),
        conclusion: job.conclusion && to_string(job.conclusion),
        elapsed: elapsed,
        current_step: job.current_step,
        steps_completed: steps_completed,
        steps_total: steps_total,
        html_url: job.html_url
      }
    }
  end

  @doc """
  Parses a workflow YAML file and populates `needs` on each Job struct.

  The GitHub REST API does not return `needs` for jobs. This function
  extracts dependencies from the workflow definition YAML and matches
  them to API job structs by display name (with matrix prefix fallback).
  """
  def resolve_job_needs(yaml_content, jobs) do
    case YamlElixir.read_from_string(yaml_content) do
      {:ok, parsed} ->
        yaml_jobs = parsed["jobs"] || %{}

        # Build yaml_key -> display_name mapping
        # Display name is the `name` field if set, otherwise the yaml key itself
        key_to_display =
          Map.new(yaml_jobs, fn {key, config} ->
            display = (is_map(config) && config["name"]) || key
            {key, display}
          end)

        # Build display_name -> [needed_display_names]
        display_to_needs =
          Map.new(yaml_jobs, fn {key, config} ->
            display = Map.get(key_to_display, key, key)

            needs_keys =
              case is_map(config) && config["needs"] do
                nil -> []
                needs when is_list(needs) -> needs
                needs when is_binary(needs) -> [needs]
                _ -> []
              end

            needed_displays = Enum.map(needs_keys, &Map.get(key_to_display, &1, &1))
            {display, needed_displays}
          end)

        # For each API job, find its needs via exact or prefix match
        Enum.map(jobs, fn job ->
          needs =
            case Map.get(display_to_needs, job.name) do
              nil ->
                # Try prefix match for matrix jobs (API name starts with YAML display name)
                display_to_needs
                |> Enum.find(fn {display, _} ->
                  display != job.name && String.starts_with?(job.name, display)
                end)
                |> case do
                  {_, needs} -> needs
                  nil -> []
                end

              needs ->
                needs
            end

          %{job | needs: needs}
        end)

      {:error, _} ->
        jobs
    end
  end

  def serialize_workflow_runs(workflow_runs) do
    Enum.map(workflow_runs, fn run ->
      %{
        id: run.id,
        jobs:
          Enum.map(run.jobs, fn job ->
            steps_completed = Enum.count(job.steps, &(&1.status == :completed))
            steps_total = length(job.steps)

            elapsed =
              if job.started_at do
                end_time = job.completed_at || DateTime.utc_now()
                DateTime.diff(end_time, job.started_at, :second)
              else
                0
              end

            %{
              id: job.id,
              name: job.name,
              status: to_string(job.status),
              conclusion: job.conclusion && to_string(job.conclusion),
              elapsed: elapsed,
              current_step: job.current_step,
              steps_completed: steps_completed,
              steps_total: steps_total,
              html_url: job.html_url,
              needs: job.needs || []
            }
          end)
      }
    end)
  end
end
