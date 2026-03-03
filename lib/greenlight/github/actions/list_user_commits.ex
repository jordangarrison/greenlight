defmodule Greenlight.GitHub.Actions.ListUserCommits do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    username = query.arguments.username

    case Client.search_user_commits(username) do
      {:ok, commits} ->
        ash_commits =
          Enum.map(commits, fn c ->
            %Greenlight.GitHub.UserCommit{
              sha: c.sha,
              message: c.message,
              repo: c.repo,
              html_url: c.html_url,
              authored_at: c.authored_at
            }
          end)

        {:ok, ash_commits}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
