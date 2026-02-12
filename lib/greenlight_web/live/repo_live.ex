defmodule GreenlightWeb.RepoLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client

  @impl true
  def mount(%{"owner" => owner, "repo" => repo}, _session, socket) do
    socket =
      assign(socket,
        owner: owner,
        repo: repo,
        active_tab: "commits",
        page_title: "#{owner}/#{repo}",
        commits: [],
        pulls: [],
        branches: [],
        releases: [],
        loading: true
      )

    if connected?(socket) do
      send(self(), :load_data)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_data, socket) do
    %{owner: owner, repo: repo} = socket.assigns

    pulls =
      case Client.list_pulls(owner, repo) do
        {:ok, data} -> data
        {:error, _} -> []
      end

    branches =
      case Client.list_branches(owner, repo) do
        {:ok, data} -> data
        {:error, _} -> []
      end

    releases =
      case Client.list_releases(owner, repo) do
        {:ok, data} -> data
        {:error, _} -> []
      end

    # Fetch recent workflow runs for the "commits" tab
    commits =
      case Client.list_workflow_runs(owner, repo, per_page: 20) do
        {:ok, runs} ->
          runs
          |> Enum.uniq_by(& &1.head_sha)
          |> Enum.take(20)

        {:error, _} ->
          []
      end

    {:noreply,
     assign(socket,
       commits: commits,
       pulls: pulls,
       branches: branches,
       releases: releases,
       loading: false
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <div class="mb-6">
          <.link
            navigate={~p"/dashboard"}
            class="text-sm text-gray-500 hover:text-blue-600 transition-colors"
          >
            ← Dashboard
          </.link>
          <h1 class="text-2xl font-bold mt-2">{@owner}/{@repo}</h1>
        </div>

        <div class="flex border-b border-gray-200 dark:border-gray-700 mb-6">
          <button
            :for={tab <- ["pulls", "branches", "releases", "commits"]}
            phx-click="switch_tab"
            phx-value-tab={tab}
            class={[
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors capitalize",
              if(@active_tab == tab,
                do: "border-blue-500 text-blue-600",
                else: "border-transparent text-gray-500 hover:text-gray-700"
              )
            ]}
          >
            {tab}
          </button>
        </div>

        <div :if={@loading} class="text-center py-8 text-gray-500">Loading...</div>

        <div :if={!@loading}>
          <div :if={@active_tab == "commits"} class="space-y-2">
            <.link
              :for={run <- @commits}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{run.head_sha}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center justify-between">
                <span class="font-mono text-sm">{String.slice(run.head_sha, 0, 7)}</span>
                <span class={[
                  "text-xs px-2 py-0.5 rounded-full",
                  status_badge_class(run.status, run.conclusion)
                ]}>
                  {run.conclusion || run.status}
                </span>
              </div>
              <div class="text-sm text-gray-500 mt-1">{run.name} · {run.event}</div>
            </.link>
            <div :if={@commits == []} class="text-center py-8 text-gray-500">
              No recent workflow runs
            </div>
          </div>

          <div :if={@active_tab == "pulls"} class="space-y-2">
            <.link
              :for={pr <- @pulls}
              navigate={~p"/repos/#{@owner}/#{@repo}/pull/#{pr.number}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center gap-2">
                <span class="text-gray-500">#{pr.number}</span>
                <span class="font-medium text-sm">{pr.title}</span>
              </div>
            </.link>
            <div :if={@pulls == []} class="text-center py-8 text-gray-500">
              No open pull requests
            </div>
          </div>

          <div :if={@active_tab == "branches"} class="space-y-2">
            <.link
              :for={branch <- @branches}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{branch.sha}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <span class="font-medium text-sm">{branch.name}</span>
            </.link>
            <div :if={@branches == []} class="text-center py-8 text-gray-500">No branches</div>
          </div>

          <div :if={@active_tab == "releases"} class="space-y-2">
            <.link
              :for={release <- @releases}
              navigate={~p"/repos/#{@owner}/#{@repo}/release/#{release.tag_name}"}
              class="block p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 transition-colors"
            >
              <div class="flex items-center gap-2">
                <span class="font-mono text-sm">{release.tag_name}</span>
                <span :if={release.name} class="text-sm text-gray-500">{release.name}</span>
              </div>
            </.link>
            <div :if={@releases == []} class="text-center py-8 text-gray-500">No releases</div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] ->
        "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"

      s when s in [:failure, "failure"] ->
        "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"

      s when s in [:in_progress, "in_progress"] ->
        "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200"

      _ ->
        "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"
    end
  end
end
