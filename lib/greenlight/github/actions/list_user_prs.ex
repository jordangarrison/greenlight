defmodule Greenlight.GitHub.Actions.ListUserPRs do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Greenlight.GitHub.Client

  def read(query, _data_layer_query, _opts, _context) do
    username = query.arguments.username

    opts =
      [:per_page]
      |> Enum.map(fn key -> {key, Map.get(query.arguments, key)} end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Client.search_user_prs(username, opts) do
      {:ok, prs} ->
        ash_prs =
          Enum.map(prs, fn pr ->
            %Greenlight.GitHub.UserPR{
              number: pr.number,
              title: pr.title,
              state: pr.state,
              html_url: pr.html_url,
              updated_at: pr.updated_at,
              repo: pr.repo
            }
          end)

        {:ok, ash_prs}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
