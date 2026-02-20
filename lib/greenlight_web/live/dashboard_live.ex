defmodule GreenlightWeb.DashboardLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client
  alias Greenlight.WideEvent

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
        expanded_orgs: MapSet.new()
      )

    WideEvent.add(
      live_view: "DashboardLive",
      bookmarked_repos_count: length(bookmarked),
      followed_orgs_count: length(orgs),
      connected: connected?(socket)
    )

    WideEvent.emit("liveview.mounted", [], level: :debug)

    if connected?(socket) do
      send(self(), :load_org_repos)
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
