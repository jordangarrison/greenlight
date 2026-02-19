defmodule GreenlightWeb.DashboardLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client
  import Greenlight.TimeHelpers, only: [relative_time: 1]

  @impl true
  def mount(_params, _session, socket) do
    bookmarked = Greenlight.Config.bookmarked_repos()
    orgs = Greenlight.Config.followed_orgs()

    socket =
      assign(socket,
        page_title: "Dashboard",
        bookmarked_repos: bookmarked,
        followed_orgs: orgs,
        org_repos: %{},
        expanded_orgs: MapSet.new(),
        user: nil,
        user_prs: [],
        user_commits: [],
        user_loading: true
      )

    if connected?(socket) do
      send(self(), :load_org_repos)
      send(self(), :load_user)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_org_repos, socket) do
    org_repos =
      socket.assigns.followed_orgs
      |> Enum.reduce(%{}, fn org, acc ->
        case Client.list_org_repos(org) do
          {:ok, repos} -> Map.put(acc, org, repos)
          {:error, _} -> Map.put(acc, org, [])
        end
      end)

    {:noreply, assign(socket, org_repos: org_repos)}
  end

  @impl true
  def handle_info(:load_user, socket) do
    case Client.get_authenticated_user() do
      {:ok, user} ->
        send(self(), :load_user_activity)
        {:noreply, assign(socket, user: user)}

      {:error, _} ->
        {:noreply, assign(socket, user_loading: false)}
    end
  end

  @impl true
  def handle_info(:load_user_activity, socket) do
    username = socket.assigns.user.login

    prs_task = Task.async(fn -> Client.search_user_prs(username) end)
    commits_task = Task.async(fn -> Client.search_user_commits(username) end)

    prs =
      case Task.await(prs_task) do
        {:ok, prs} -> prs
        {:error, _} -> []
      end

    commits =
      case Task.await(commits_task) do
        {:ok, commits} -> commits
        {:error, _} -> []
      end

    {:noreply, assign(socket, user_prs: prs, user_commits: commits, user_loading: false)}
  end

  @impl true
  def handle_event("toggle_org", %{"org" => org}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_orgs, org) do
        MapSet.delete(socket.assigns.expanded_orgs, org)
      else
        MapSet.put(socket.assigns.expanded_orgs, org)
      end

    {:noreply, assign(socket, expanded_orgs: expanded)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-6xl mx-auto">
        <h1 class="text-4xl font-bold uppercase tracking-wider text-white mb-10">
          Dashboard
        </h1>

        <%!-- User Insights Section --%>
        <section class="mb-12">
          <%!-- Loading state --%>
          <div :if={@user_loading} class="nb-card p-6 mb-6">
            <div class="flex items-center gap-4 animate-pulse">
              <div class="w-10 h-10 bg-[var(--gl-border)] rounded-full" />
              <div class="h-4 w-48 bg-[var(--gl-border)]" />
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
              <div :for={_ <- 1..2} class="space-y-3">
                <div class="h-3 w-32 bg-[var(--gl-border)]" />
                <div :for={_ <- 1..3} class="h-10 bg-[var(--gl-border)]" />
              </div>
            </div>
          </div>

          <%!-- Loaded state --%>
          <div :if={@user != nil and not @user_loading}>
            <%!-- Compact profile bar --%>
            <div class="flex items-center gap-3 mb-6">
              <img
                src={@user.avatar_url}
                alt={@user.login}
                class="w-10 h-10 rounded-full border-2 border-[var(--gl-accent)]"
              />
              <div>
                <span class="text-lg font-bold text-white">{@user.login}</span>
                <span :if={@user.name} class="text-sm text-[var(--gl-text-muted)] ml-2">
                  {" · "}{@user.name}
                </span>
              </div>
            </div>

            <%!-- Two-column grid: PRs and Commits --%>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <%!-- Recent PRs column --%>
              <div>
                <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-3 flex items-center gap-2">
                  <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Pull Requests
                </h3>
                <div :if={@user_prs == []} class="text-sm text-[var(--gl-text-muted)] py-4">
                  No recent pull requests
                </div>
                <div class="space-y-2">
                  <a
                    :for={pr <- @user_prs}
                    href={pr.html_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="nb-card-muted block p-3 group"
                  >
                    <div class="flex items-start justify-between gap-2">
                      <div class="min-w-0 flex-1">
                        <span class="text-xs text-[var(--gl-text-muted)] block">{pr.repo}</span>
                        <span class="text-sm text-white font-bold group-hover:text-[var(--gl-accent)] transition-colors block truncate">
                          {pr.title}
                        </span>
                      </div>
                      <span class={[
                        "text-xs px-1.5 py-0.5 border font-bold shrink-0",
                        if(pr.state == "open",
                          do: "text-[var(--gl-status-success)] border-[var(--gl-status-success)]",
                          else: "text-[var(--gl-text-muted)] border-[var(--gl-border)]"
                        )
                      ]}>
                        {pr.state}
                      </span>
                    </div>
                    <div class="flex items-center gap-2 mt-1 text-xs text-[var(--gl-text-muted)]">
                      <span>#{pr.number}</span>
                      <span>·</span>
                      <span>{relative_time(pr.updated_at)}</span>
                    </div>
                  </a>
                </div>
              </div>

              <%!-- Recent Commits column --%>
              <div>
                <h3 class="text-sm font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-3 flex items-center gap-2">
                  <span class="w-1.5 h-1.5 bg-[var(--gl-accent)]" /> Recent Commits
                </h3>
                <div :if={@user_commits == []} class="text-sm text-[var(--gl-text-muted)] py-4">
                  No recent commits
                </div>
                <div class="space-y-2">
                  <a
                    :for={commit <- @user_commits}
                    href={commit.html_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="nb-card-muted block p-3 group"
                  >
                    <div class="min-w-0">
                      <span class="text-xs text-[var(--gl-text-muted)] block">{commit.repo}</span>
                      <span class="text-sm text-white font-bold group-hover:text-[var(--gl-accent)] transition-colors block truncate">
                        {commit.message}
                      </span>
                    </div>
                    <div class="flex items-center gap-2 mt-1 text-xs text-[var(--gl-text-muted)]">
                      <span>{String.slice(commit.sha, 0, 7)}</span>
                      <span>·</span>
                      <span>{relative_time(commit.authored_at)}</span>
                    </div>
                  </a>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section :if={@bookmarked_repos != []} class="mb-12">
          <h2 class="text-lg font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-6 flex items-center gap-2">
            <span class="w-2 h-2 bg-[var(--gl-accent)]" /> Bookmarked Repos
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            <.link
              :for={repo <- @bookmarked_repos}
              navigate={"/repos/#{repo}"}
              class="nb-card block p-5"
            >
              <span class="text-base font-bold text-white" style="font-family: var(--gl-font-mono);">
                {repo}
              </span>
              <span class="block text-xs text-[var(--gl-text-muted)] mt-2 uppercase tracking-wider">
                View pipelines &rarr;
              </span>
            </.link>
          </div>
        </section>

        <section :if={@followed_orgs != []} class="mb-12">
          <h2 class="text-lg font-bold uppercase tracking-wider text-[var(--gl-accent)] mb-6 flex items-center gap-2">
            <span class="w-2 h-2 bg-[var(--gl-accent)]" /> Organizations
          </h2>
          <div :for={org <- @followed_orgs} class="mb-4">
            <button
              phx-click="toggle_org"
              phx-value-org={org}
              class="flex items-center gap-3 w-full text-left p-4 border-2 border-[var(--gl-border)] border-l-4 border-l-[var(--gl-accent)] bg-[var(--gl-bg-raised)] hover:bg-[var(--gl-bg-surface)] transition-colors cursor-pointer"
            >
              <span class="text-sm text-[var(--gl-accent)]" style="font-family: var(--gl-font-mono);">
                {if MapSet.member?(@expanded_orgs, org), do: "[-]", else: "[+]"}
              </span>
              <span class="font-bold text-white" style="font-family: var(--gl-font-mono);">
                {org}
              </span>
              <span
                class="text-sm text-[var(--gl-text-muted)] ml-auto"
                style="font-family: var(--gl-font-mono);"
              >
                {length(Map.get(@org_repos, org, []))} repos
              </span>
            </button>

            <div :if={MapSet.member?(@expanded_orgs, org)} class="mt-2 ml-6 space-y-2">
              <.link
                :for={repo <- Map.get(@org_repos, org, [])}
                navigate={"/repos/#{repo}"}
                class="nb-card-muted block p-3"
              >
                <span
                  class="text-sm text-[var(--gl-text-body)]"
                  style="font-family: var(--gl-font-mono);"
                >
                  {repo}
                </span>
              </.link>
            </div>
          </div>
        </section>

        <div
          :if={@bookmarked_repos == [] and @followed_orgs == []}
          class="text-center py-20"
        >
          <div class="nb-card inline-block p-8 text-left max-w-md">
            <p class="text-xl font-bold text-white uppercase tracking-wider mb-4">
              No repos configured
            </p>
            <p class="text-sm text-[var(--gl-text-muted)] mb-3">Set these environment variables:</p>
            <code
              class="block p-3 bg-[var(--gl-bg-primary)] border border-[var(--gl-border)] text-[var(--gl-accent)] text-xs mb-2"
              style="font-family: var(--gl-font-mono);"
            >
              GREENLIGHT_BOOKMARKED_REPOS
            </code>
            <code
              class="block p-3 bg-[var(--gl-bg-primary)] border border-[var(--gl-border)] text-[var(--gl-accent)] text-xs"
              style="font-family: var(--gl-font-mono);"
            >
              GREENLIGHT_FOLLOWED_ORGS
            </code>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
