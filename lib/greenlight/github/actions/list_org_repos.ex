defmodule Greenlight.GitHub.Actions.ListOrgRepos do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    org = query.arguments.org

    case Client.list_org_repos(org) do
      {:ok, full_names} ->
        repos =
          Enum.map(full_names, fn full_name ->
            [owner, name] = String.split(full_name, "/", parts: 2)

            %Greenlight.GitHub.Repository{
              full_name: full_name,
              name: name,
              owner: owner
            }
          end)

        {:ok, repos}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
