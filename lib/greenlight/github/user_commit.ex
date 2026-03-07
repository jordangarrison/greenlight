defmodule Greenlight.GitHub.UserCommit do
  @moduledoc """
  A commit authored by the authenticated user (from GitHub search).
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute(:sha, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:message, :string, public?: true)
    attribute(:repo, :string, public?: true)
    attribute(:html_url, :string, public?: true)
    attribute(:authored_at, :string, public?: true)
  end

  actions do
    read :list do
      argument(:username, :string, allow_nil?: false)
      argument(:per_page, :integer)

      manual(Greenlight.GitHub.Actions.ListUserCommits)
    end
  end
end
