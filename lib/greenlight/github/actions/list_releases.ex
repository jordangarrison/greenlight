defmodule Greenlight.GitHub.Actions.ListReleases do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    owner = query.arguments.owner
    repo = query.arguments.repo

    case Client.list_releases(owner, repo) do
      {:ok, releases} ->
        ash_releases =
          Enum.map(releases, fn r ->
            %Greenlight.GitHub.Release{
              tag_name: r.tag_name,
              name: r.name
            }
          end)

        {:ok, ash_releases}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
