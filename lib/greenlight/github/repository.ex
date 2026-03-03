defmodule Greenlight.GitHub.Repository do
  @moduledoc """
  A GitHub repository.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :full_name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :owner, :string, public?: true
  end

  actions do
    read :list_for_org do
      argument :org, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListOrgRepos
    end
  end
end
