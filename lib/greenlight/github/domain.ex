defmodule Greenlight.GitHub do
  @moduledoc """
  Ash Domain for GitHub API resources.
  All GitHub data access goes through this domain.
  """

  use Ash.Domain

  resources do
    resource Greenlight.GitHub.WorkflowRun do
      define(:list_workflow_runs, action: :list, args: [:owner, :repo])
      define(:get_workflow_run, action: :get, args: [:owner, :repo, :run_id])
    end

    resource Greenlight.GitHub.Job do
      define(:list_jobs, action: :list, args: [:owner, :repo, :run_id])
    end

    resource Greenlight.GitHub.Repository do
      define(:list_org_repos, action: :list_for_org, args: [:org])
    end

    resource Greenlight.GitHub.Pull do
      define(:list_pulls, action: :list, args: [:owner, :repo])
    end

    resource Greenlight.GitHub.Branch do
      define(:list_branches, action: :list, args: [:owner, :repo])
    end

    resource Greenlight.GitHub.Release do
      define(:list_releases, action: :list, args: [:owner, :repo])
    end

    resource Greenlight.GitHub.User do
      define(:get_authenticated_user, action: :me)
    end

    resource Greenlight.GitHub.UserPR do
      define(:list_user_prs, action: :list, args: [:username])
    end

    resource Greenlight.GitHub.UserCommit do
      define(:list_user_commits, action: :list, args: [:username])
    end
  end
end
