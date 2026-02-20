defmodule Greenlight.GitHub.Client do
  @moduledoc """
  HTTP client for the GitHub REST API, using Req.
  """

  alias Greenlight.GitHub.Models
  alias Greenlight.GitHub.ReqLogger

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

    Req.new(opts) |> ReqLogger.attach()
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

  def get_repo_content(owner, repo, path, ref) do
    case Req.get(new(), url: "/repos/#{owner}/#{repo}/contents/#{path}", params: %{ref: ref}) do
      {:ok, %{status: 200, body: %{"content" => content, "encoding" => "base64"}}} ->
        decoded = content |> String.replace(~r/\s/, "") |> Base.decode64!()
        {:ok, decoded}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_authenticated_user do
    case Req.get(new(), url: "/user") do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           login: body["login"],
           name: body["name"],
           avatar_url: body["avatar_url"]
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_user_prs(username) do
    case Req.get(new(),
           url: "/search/issues",
           params: %{q: "author:#{username} type:pr sort:updated", per_page: 5}
         ) do
      {:ok, %{status: 200, body: body}} ->
        prs =
          Enum.map(body["items"], fn item ->
            repo =
              item["repository_url"]
              |> String.replace("https://api.github.com/repos/", "")

            %{
              number: item["number"],
              title: item["title"],
              state: item["state"],
              html_url: item["html_url"],
              updated_at: item["updated_at"],
              repo: repo
            }
          end)

        {:ok, prs}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_user_commits(username) do
    case Req.get(new(),
           url: "/search/commits",
           params: %{q: "author:#{username} sort:author-date", per_page: 5}
         ) do
      {:ok, %{status: 200, body: body}} ->
        commits =
          Enum.map(body["items"], fn item ->
            message =
              item["commit"]["message"]
              |> String.split("\n", parts: 2)
              |> List.first()

            %{
              sha: item["sha"],
              message: message,
              repo: item["repository"]["full_name"],
              html_url: item["html_url"],
              authored_at: item["commit"]["author"]["date"]
            }
          end)

        {:ok, commits}

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
