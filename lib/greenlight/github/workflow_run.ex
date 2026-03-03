defmodule Greenlight.GitHub.WorkflowRun do
  @moduledoc """
  A GitHub Actions workflow run.
  """

  use Ash.Resource,
    domain: Greenlight.GitHub

  attributes do
    attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, public?: true
    attribute :workflow_id, :integer, public?: true
    attribute :status, :atom, public?: true
    attribute :conclusion, :atom, public?: true
    attribute :head_sha, :string, public?: true
    attribute :event, :string, public?: true
    attribute :html_url, :string, public?: true
    attribute :path, :string, public?: true
    attribute :created_at, :utc_datetime, public?: true
    attribute :updated_at, :utc_datetime, public?: true
    attribute :owner, :string, public?: true
    attribute :repo, :string, public?: true
    attribute :jobs, {:array, :map}, default: [], public?: true
  end

  actions do
    read :list do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :head_sha, :string
      argument :event, :string
      argument :per_page, :integer

      manual Greenlight.GitHub.Actions.ListWorkflowRuns
    end

    read :get do
      argument :owner, :string, allow_nil?: false
      argument :repo, :string, allow_nil?: false
      argument :run_id, :integer, allow_nil?: false

      get? true

      manual Greenlight.GitHub.Actions.GetWorkflowRun
    end
  end
end
