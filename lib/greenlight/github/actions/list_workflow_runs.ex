defmodule Greenlight.GitHub.Actions.ListWorkflowRuns do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client
  alias Greenlight.GitHub.Actions.Parsing

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    opts =
      [:head_sha, :event, :per_page]
      |> Enum.map(fn key -> {key, Map.get(query.arguments, key)} end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case Client.list_workflow_runs(owner, repo, opts) do
      {:ok, runs} ->
        ash_runs = Enum.map(runs, &to_resource(&1, owner, repo))
        {:ok, ash_runs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_resource(run, owner, repo) do
    %Greenlight.GitHub.WorkflowRun{
      id: run["id"],
      name: run["name"],
      workflow_id: run["workflow_id"],
      status: Parsing.parse_status(run["status"]),
      conclusion: Parsing.parse_conclusion(run["conclusion"]),
      head_sha: run["head_sha"],
      event: run["event"],
      html_url: run["html_url"],
      path: run["path"],
      created_at: Parsing.parse_datetime(run["created_at"]),
      updated_at: Parsing.parse_datetime(run["updated_at"]),
      owner: owner,
      repo: repo,
      jobs: []
    }
  end
end
