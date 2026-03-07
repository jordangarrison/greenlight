defmodule GreenlightWeb.UserCommitsLive do
  use GreenlightWeb, :live_view

  alias Greenlight.GitHub.UserInsightsServer
  import Greenlight.TimeHelpers, only: [relative_time: 1]

  @page_size 10

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    cached = UserInsightsServer.get_cached()

    if connected?(socket), do: UserInsightsServer.subscribe()

    {:ok,
     assign(socket,
       page_title: "#{username} · Commits",
       username: username,
       all_commits: cached.commits
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    all_commits = socket.assigns.all_commits
    total = length(all_commits)
    total_pages = max(ceil(total / @page_size), 1)
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1) |> min(total_pages)
    items = Enum.slice(all_commits, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       page: page,
       total_pages: total_pages,
       commits: items
     )}
  end

  @impl true
  def handle_info({:user_insights_update, data}, socket) do
    all_commits = data.commits
    total = length(all_commits)
    total_pages = max(ceil(total / @page_size), 1)
    page = min(socket.assigns.page, total_pages)
    items = Enum.slice(all_commits, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       all_commits: all_commits,
       page: page,
       total_pages: total_pages,
       commits: items
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center gap-3 mb-8">
          <.link navigate="/" class="text-[var(--gl-text-muted)] hover:text-white transition-colors">
            <.icon name="hero-arrow-left" class="w-5 h-5" />
          </.link>
          <h1 class="text-3xl font-bold uppercase tracking-wider text-white">
            Commits
          </h1>
          <span class="text-lg text-[var(--gl-text-muted)]">
            · {@username}
          </span>
        </div>

        <div :if={@commits == []} class="nb-card p-8 text-center">
          <p class="text-[var(--gl-text-muted)]">No commits found</p>
        </div>

        <div class="space-y-2">
          <.link
            :for={commit <- @commits}
            navigate={"/repos/#{commit.repo}/commit/#{commit.sha}"}
            class="nb-card-muted block p-4 group"
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
          </.link>
        </div>

        <div
          :if={@total_pages > 1}
          id="commits-pagination"
          class="flex items-center justify-center gap-4 mt-8"
        >
          <.link
            :if={@page > 1}
            patch={"/#{@username}/commits?page=#{@page - 1}"}
            id="commits-prev"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            &larr; Previous
          </.link>
          <span class="text-sm text-[var(--gl-text-muted)]">
            Page {@page} of {@total_pages}
          </span>
          <.link
            :if={@page < @total_pages}
            patch={"/#{@username}/commits?page=#{@page + 1}"}
            id="commits-next"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            Next &rarr;
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
