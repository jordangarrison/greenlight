defmodule Greenlight.GitHub.UserPR do
  @moduledoc """
  A pull request authored by the authenticated user (from GitHub search).
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute(:html_url, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:number, :integer, public?: true)
    attribute(:title, :string, public?: true)
    attribute(:state, :string, public?: true)
    attribute(:updated_at, :string, public?: true)
    attribute(:repo, :string, public?: true)
  end

  actions do
    read :list do
      argument(:username, :string, allow_nil?: false)
      argument(:per_page, :integer)

      manual(Greenlight.GitHub.Actions.ListUserPRs)
    end
  end
end
