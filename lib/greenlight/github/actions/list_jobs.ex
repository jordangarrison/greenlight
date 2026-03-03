defmodule Greenlight.GitHub.Actions.ListJobs do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client
  alias Greenlight.GitHub.Actions.Parsing

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo
    run_id = query.arguments.run_id

    case Client.list_jobs(owner, repo, run_id) do
      {:ok, jobs} ->
        ash_jobs = Enum.map(jobs, &to_resource(&1, owner, repo, run_id))
        {:ok, ash_jobs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(job, owner, repo, run_id) do
    steps =
      Enum.map(job.steps, fn step ->
        %Greenlight.GitHub.Step{
          name: step.name,
          status: Parsing.parse_status(step.status),
          conclusion: Parsing.parse_conclusion(step.conclusion),
          number: step.number,
          started_at: Parsing.parse_datetime(step.started_at),
          completed_at: Parsing.parse_datetime(step.completed_at)
        }
      end)

    %Greenlight.GitHub.Job{
      id: job.id,
      name: job.name,
      status: Parsing.parse_status(job.status),
      conclusion: Parsing.parse_conclusion(job.conclusion),
      started_at: Parsing.parse_datetime(job.started_at),
      completed_at: Parsing.parse_datetime(job.completed_at),
      current_step: job.current_step,
      html_url: job.html_url,
      steps: steps,
      needs: job.needs || [],
      owner: owner,
      repo: repo,
      run_id: run_id
    }
  end
end
