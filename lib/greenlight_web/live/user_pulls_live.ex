defmodule GreenlightWeb.UserPullsLive do
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
       page_title: "#{username} · Pull Requests",
       username: username,
       all_prs: cached.prs
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    all_prs = socket.assigns.all_prs
    total = length(all_prs)
    total_pages = max(ceil(total / @page_size), 1)
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1) |> min(total_pages)
    items = Enum.slice(all_prs, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       page: page,
       total_pages: total_pages,
       prs: items
     )}
  end

  @impl true
  def handle_info({:user_insights_update, data}, socket) do
    all_prs = data.prs
    total = length(all_prs)
    total_pages = max(ceil(total / @page_size), 1)
    page = min(socket.assigns.page, total_pages)
    items = Enum.slice(all_prs, (page - 1) * @page_size, @page_size)

    {:noreply,
     assign(socket,
       all_prs: all_prs,
       page: page,
       total_pages: total_pages,
       prs: items
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
            Pull Requests
          </h1>
          <span class="text-lg text-[var(--gl-text-muted)]">
            · {@username}
          </span>
        </div>

        <div :if={@prs == []} class="nb-card p-8 text-center">
          <p class="text-[var(--gl-text-muted)]">No pull requests found</p>
        </div>

        <div class="space-y-2">
          <.link
            :for={pr <- @prs}
            navigate={"/repos/#{pr.repo}/pull/#{pr.number}"}
            class="nb-card-muted block p-4 group"
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
          </.link>
        </div>

        <div
          :if={@total_pages > 1}
          id="pulls-pagination"
          class="flex items-center justify-center gap-4 mt-8"
        >
          <.link
            :if={@page > 1}
            patch={"/#{@username}/pulls?page=#{@page - 1}"}
            id="pulls-prev"
            class="nb-card-muted px-4 py-2 text-sm font-bold text-white hover:text-[var(--gl-accent)] transition-colors"
          >
            &larr; Previous
          </.link>
          <span class="text-sm text-[var(--gl-text-muted)]">
            Page {@page} of {@total_pages}
          </span>
          <.link
            :if={@page < @total_pages}
            patch={"/#{@username}/pulls?page=#{@page + 1}"}
            id="pulls-next"
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
