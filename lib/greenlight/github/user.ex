defmodule Greenlight.GitHub.User do
  @moduledoc """
  An authenticated GitHub user.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :login, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :avatar_url, :string, public?: true
  end

  actions do
    read :me do
      manual Greenlight.GitHub.Actions.GetAuthenticatedUser
    end
  end
end
