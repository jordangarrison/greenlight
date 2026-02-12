defmodule Greenlight.Config do
  @moduledoc """
  Application configuration helpers.
  """

  def github_token do
    Application.get_env(:greenlight, :github_token) ||
      raise "GITHUB_TOKEN environment variable is not set"
  end

  def bookmarked_repos do
    Application.get_env(:greenlight, :bookmarked_repos, [])
  end

  def followed_orgs do
    Application.get_env(:greenlight, :followed_orgs, [])
  end
end
