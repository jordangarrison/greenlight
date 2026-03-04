defmodule Greenlight.GitHub.Actions.ListPulls do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_pulls(owner, repo) do
      {:ok, pulls} ->
        ash_pulls =
          Enum.map(pulls, fn pr ->
            %Greenlight.GitHub.Pull{
              number: pr.number,
              title: pr.title,
              head_sha: pr.head_sha
            }
          end)

        {:ok, ash_pulls}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
