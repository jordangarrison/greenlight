defmodule Greenlight.GitHub.Actions.ListBranches do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_branches(owner, repo) do
      {:ok, branches} ->
        ash_branches =
          Enum.map(branches, fn b ->
            %Greenlight.GitHub.Branch{
              name: b.name,
              sha: b.sha
            }
          end)

        {:ok, ash_branches}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
