defmodule GreenlightWeb.DashboardLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.Client

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
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold mb-8">Greenlight</h1>

        <section :if={@bookmarked_repos != []} class="mb-10">
          <h2 class="text-lg font-semibold mb-4">Bookmarked Repos</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.link
              :for={repo <- @bookmarked_repos}
              navigate={"/repos/#{repo}"}
              class="block p-4 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-blue-400 dark:hover:border-blue-500 transition-colors"
            >
              <span class="font-medium">{repo}</span>
            </.link>
          </div>
        </section>

        <section :if={@followed_orgs != []} class="mb-10">
          <h2 class="text-lg font-semibold mb-4">Organizations</h2>
          <div :for={org <- @followed_orgs} class="mb-4">
            <button
              phx-click="toggle_org"
              phx-value-org={org}
              class="flex items-center gap-2 w-full text-left p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <span class="text-xs">
                {if MapSet.member?(@expanded_orgs, org), do: "▼", else: "▶"}
              </span>
              <span class="font-medium">{org}</span>
              <span class="text-sm text-gray-500 ml-auto">
                {length(Map.get(@org_repos, org, []))} repos
              </span>
            </button>

            <div :if={MapSet.member?(@expanded_orgs, org)} class="mt-2 ml-6 space-y-1">
              <.link
                :for={repo <- Map.get(@org_repos, org, [])}
                navigate={"/repos/#{repo}"}
                class="block p-2 rounded text-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                {repo}
              </.link>
            </div>
          </div>
        </section>

        <div
          :if={@bookmarked_repos == [] and @followed_orgs == []}
          class="text-center py-16 text-gray-500"
        >
          <p class="text-lg mb-2">No repos configured yet</p>
          <p class="text-sm">
            Set
            <code class="bg-gray-100 dark:bg-gray-800 px-1 rounded">
              GREENLIGHT_BOOKMARKED_REPOS
            </code>
            and
            <code class="bg-gray-100 dark:bg-gray-800 px-1 rounded">GREENLIGHT_FOLLOWED_ORGS</code>
            environment variables
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
