defmodule Greenlight.GitHub.Pull do
  @moduledoc """
  A GitHub pull request.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :number, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :title, :string, public?: true
    attribute :head_sha, :string, public?: true
    attribute :state, :string, public?: true
    attribute :html_url, :string, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListPulls
    end
  end
end
