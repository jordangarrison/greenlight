defmodule Greenlight.GitHub.Client do
  @moduledoc """
  HTTP client for the GitHub REST API, using Req.
  """

  alias Greenlight.GitHub.Models

  @base_url "https://api.github.com"

  defp new do
    opts = [
      base_url: @base_url,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"authorization", "Bearer #{Greenlight.Config.github_token()}"},
        {"x-github-api-version", "2022-11-28"}
      ]
    ]

    opts =
      if Application.get_env(:greenlight, :req_test_mode) do
        Keyword.put(opts, :plug, {Req.Test, __MODULE__})
      else
        opts
      end

    Req.new(opts)
  end

  def list_workflow_runs(owner, repo, opts \\ []) do
    params = Enum.into(opts, %{})

    case Req.get(new(), url: "/repos/#{owner}/#{repo}/actions/runs", params: params) do
      {:ok, %{status: 200, body: body}} ->
        runs = Enum.map(body["workflow_runs"], &Models.WorkflowRun.from_api/1)
        {:ok, runs}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_jobs(owner, repo, run_id) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs") do
      {:ok, %{status: 200, body: body}} ->
        jobs = Enum.map(body["jobs"], &Models.Job.from_api/1)
        {:ok, jobs}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_org_repos(org) do
    case Req.get(new(), url: "/orgs/#{org}/repos", params: %{per_page: 100, sort: "pushed"}) do
      {:ok, %{status: 200, body: body}} ->
        repos = Enum.map(body, & &1["full_name"])
        {:ok, repos}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_pulls(owner, repo) do
    case Req.get(new(),
           url: "/repos/#{owner}/#{repo}/pulls",
           params: %{state: "open", per_page: 30}
         ) do
      {:ok, %{status: 200, body: body}} ->
        pulls =
          Enum.map(body, fn pr ->
            %{number: pr["number"], title: pr["title"], head_sha: pr["head"]["sha"]}
          end)

        {:ok, pulls}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_branches(owner, repo) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/branches", params: %{per_page: 30}) do
      {:ok, %{status: 200, body: body}} ->
        branches =
          Enum.map(body, fn b ->
            %{name: b["name"], sha: b["commit"]["sha"]}
          end)

        {:ok, branches}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_releases(owner, repo) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/releases", params: %{per_page: 30}) do
      {:ok, %{status: 200, body: body}} ->
        releases =
          Enum.map(body, fn r ->
            %{tag_name: r["tag_name"], name: r["name"]}
          end)

        {:ok, releases}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
