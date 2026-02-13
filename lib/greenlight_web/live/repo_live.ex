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
      <div class="max-w-5xl mx-auto">
        <div class="mb-8">
          <.link
            navigate={~p"/dashboard"}
            class="text-sm text-[var(--gl-text-muted)] hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
            style="font-family: var(--gl-font-mono);"
          >
            &larr; Dashboard
          </.link>
          <h1 class="text-3xl font-bold mt-3 text-white" style="font-family: var(--gl-font-mono);">
            {@owner}<span class="text-[var(--gl-text-muted)]">/</span>{@repo}
          </h1>
        </div>

        <div class="flex border-b-[3px] border-[var(--gl-border)] mb-8">
          <button
            :for={tab <- ["pulls", "branches", "releases", "commits"]}
            phx-click="switch_tab"
            phx-value-tab={tab}
            class={[
              "px-5 py-3 text-sm font-bold uppercase tracking-wider border-b-[3px] -mb-[3px] transition-colors cursor-pointer",
              if(@active_tab == tab,
                do: "border-[var(--gl-accent)] text-[var(--gl-accent)]",
                else: "border-transparent text-[var(--gl-text-muted)] hover:text-white"
              )
            ]}
            style="font-family: var(--gl-font-mono);"
          >
            {tab}
          </button>
        </div>

        <div
          :if={@loading}
          class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider"
        >
          <.icon name="hero-arrow-path" class="size-5 motion-safe:animate-spin inline mr-2" />
          Loading...
        </div>

        <div :if={!@loading}>
          <div :if={@active_tab == "commits"} class="space-y-3">
            <.link
              :for={run <- @commits}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{run.head_sha}"}
              class={["nb-card block p-4", status_border_class(run.status, run.conclusion)]}
            >
              <div class="flex items-center justify-between">
                <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                  {String.slice(run.head_sha, 0, 7)}
                </span>
                <span
                  class={[
                    "text-xs px-3 py-1 font-bold uppercase tracking-wider border",
                    status_badge_class(run.status, run.conclusion)
                  ]}
                  style="font-family: var(--gl-font-mono);"
                >
                  {run.conclusion || run.status}
                </span>
              </div>
              <div
                class="text-sm text-[var(--gl-text-muted)] mt-2"
                style="font-family: var(--gl-font-mono);"
              >
                {run.name}
              </div>
            </.link>
            <div
              :if={@commits == []}
              class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider"
            >
              No recent workflow runs
            </div>
          </div>

          <div :if={@active_tab == "pulls"} class="space-y-3">
            <.link
              :for={pr <- @pulls}
              navigate={~p"/repos/#{@owner}/#{@repo}/pull/#{pr.number}"}
              class="nb-card block p-4"
            >
              <div class="flex items-center gap-3">
                <span
                  class="text-[var(--gl-text-muted)] text-sm"
                  style="font-family: var(--gl-font-mono);"
                >
                  #{pr.number}
                </span>
                <span class="font-bold text-white text-sm">{pr.title}</span>
              </div>
            </.link>
            <div
              :if={@pulls == []}
              class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider"
            >
              No open pull requests
            </div>
          </div>

          <div :if={@active_tab == "branches"} class="space-y-3">
            <.link
              :for={branch <- @branches}
              navigate={~p"/repos/#{@owner}/#{@repo}/commit/#{branch.sha}"}
              class="nb-card block p-4"
            >
              <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                {branch.name}
              </span>
            </.link>
            <div
              :if={@branches == []}
              class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider"
            >
              No branches
            </div>
          </div>

          <div :if={@active_tab == "releases"} class="space-y-3">
            <.link
              :for={release <- @releases}
              navigate={~p"/repos/#{@owner}/#{@repo}/release/#{release.tag_name}"}
              class="nb-card block p-4"
            >
              <div class="flex items-center gap-3">
                <span class="font-bold text-white text-sm" style="font-family: var(--gl-font-mono);">
                  {release.tag_name}
                </span>
                <span :if={release.name} class="text-sm text-[var(--gl-text-muted)]">
                  {release.name}
                </span>
              </div>
            </.link>
            <div
              :if={@releases == []}
              class="text-center py-12 text-[var(--gl-text-muted)] uppercase tracking-wider"
            >
              No releases
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] ->
        "bg-[var(--gl-status-success)]/10 text-[var(--gl-status-success)] border-[var(--gl-status-success)]"

      s when s in [:failure, "failure"] ->
        "bg-[var(--gl-status-error)]/10 text-[var(--gl-status-error)] border-[var(--gl-status-error)]"

      s when s in [:in_progress, "in_progress"] ->
        "bg-[var(--gl-status-warning)]/10 text-[var(--gl-status-warning)] border-[var(--gl-status-warning)]"

      _ ->
        "bg-[var(--gl-border)]/20 text-[var(--gl-text-muted)] border-[var(--gl-border)]"
    end
  end

  defp status_border_class(status, conclusion) do
    case conclusion || status do
      s when s in [:success, "success"] -> "nb-status-success"
      s when s in [:failure, "failure"] -> "nb-status-error"
      s when s in [:in_progress, "in_progress"] -> "nb-status-warning"
      _ -> "nb-status-pending"
    end
  end
end
