defmodule Greenlight.GitHub.Release do
  @moduledoc """
  A GitHub release.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :tag_name, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :html_url, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListReleases
    end
  end
end
