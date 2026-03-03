defmodule Greenlight.GitHub.Job do
  @moduledoc """
  A job within a GitHub Actions workflow run.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :started_at, :utc_datetime, public?: true
    attribute :completed_at, :utc_datetime, public?: true
    attribute :current_step, :string, public?: true
    attribute :html_url, :string, public?: true
    attribute :needs, {:array, :string}, default: [], public?: true
    attribute :steps, {:array, Greenlight.GitHub.Step}, default: [], public?: true
    attribute :owner, :string, public?: true
    attribute :repo, :string, public?: true
    attribute :run_id, :integer, public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :run_id, :integer, allow_nil?: false

      manual Greenlight.GitHub.Actions.ListJobs
    end
  end
end
