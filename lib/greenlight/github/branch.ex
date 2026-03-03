defmodule Greenlight.GitHub.Branch do
  @moduledoc """
  A GitHub branch.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :sha, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListBranches
    end
  end
end
