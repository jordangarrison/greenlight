defmodule GreenlightWeb.PipelineLive do
  use GreenlightWeb, :live_view

  alias Greenlight.Pollers
  alias Greenlight.GitHub.Client
  alias Greenlight.WideEvent

  @impl true
  def mount(%{"owner" => owner, "repo" => repo, "sha" => sha}, _session, socket) do
    socket =
      socket
      |> assign(
        owner: owner,
        repo: repo,
        sha: sha,
        nodes: [],
        edges: [],
        workflow_runs: [],
        page_title: "#{owner}/#{repo} - #{String.slice(sha, 0, 7)}",
        github_url: "https://github.com/#{owner}/#{repo}/commit/#{sha}",
        github_label: String.slice(sha, 0, 7)
      )

    WideEvent.add(
      live_view: "PipelineLive",
      pipeline_owner: owner,
      pipeline_repo: repo,
      pipeline_sha: sha,
      connected: connected?(socket)
    )

    WideEvent.emit("liveview.mounted", [], level: :debug)

    if connected?(socket) do
      {:ok, state} = Pollers.subscribe(owner, repo, sha)

      socket =
        if state do
          assign(socket,
            nodes: state.nodes,
            edges: state.edges,
            workflow_runs: state.workflow_runs
          )
        else
          socket
        end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  # PR route - look up the head SHA from the PR number
  def mount(%{"owner" => owner, "repo" => repo, "number" => number}, session, socket) do
    case Client.list_pulls(owner, repo) do
      {:ok, pulls} ->
        pr = Enum.find(pulls, fn p -> p.number == String.to_integer(number) end)

        if pr do
          {:ok, socket} =
            mount(%{"owner" => owner, "repo" => repo, "sha" => pr.head_sha}, session, socket)

          {:ok,
           assign(socket,
             github_url: "https://github.com/#{owner}/#{repo}/pull/#{number}",
             github_label: "PR ##{number}"
           )}
        else
          {:ok,
           socket
           |> put_flash(:error, "PR ##{number} not found")
           |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to load PR")
         |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
    end
  end

  # Release route - look up the tag SHA
  def mount(%{"owner" => owner, "repo" => repo, "tag" => tag}, session, socket) do
    case Client.list_workflow_runs(owner, repo, event: "release") do
      {:ok, runs} ->
        run = Enum.find(runs, fn r -> r.head_sha end)

        if run do
          {:ok, socket} =
            mount(%{"owner" => owner, "repo" => repo, "sha" => run.head_sha}, session, socket)

          {:ok,
           assign(socket,
             github_url: "https://github.com/#{owner}/#{repo}/releases/tag/#{tag}",
             github_label: tag
           )}
        else
          {:ok,
           socket
           |> put_flash(:error, "No runs found for release #{tag}")
           |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to load release")
         |> push_navigate(to: ~p"/repos/#{owner}/#{repo}")}
    end
  end

  @impl true
  def handle_info(
        {:pipeline_update, %{nodes: nodes, edges: edges, workflow_runs: workflow_runs}},
        socket
      ) do
    WideEvent.emit(
      "liveview.pipeline_update",
      [
        nodes_count: length(nodes),
        edges_count: length(edges),
        workflow_runs_count: length(workflow_runs)
      ],
      level: :debug
    )

    {:noreply, assign(socket, nodes: nodes, edges: edges, workflow_runs: workflow_runs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="px-4">
        <div class="mb-4">
          <div
            class="flex items-center gap-2 text-sm text-[var(--gl-text-muted)] mb-2"
            style="font-family: var(--gl-font-mono);"
          >
            <.link
              navigate={~p"/repos/#{@owner}/#{@repo}"}
              class="hover:text-[var(--gl-accent)] transition-colors uppercase tracking-wider"
            >
              {@owner}/{@repo}
            </.link>
            <span class="text-[var(--gl-border)]">/</span>
            <span class="text-[var(--gl-accent)]">{String.slice(@sha, 0, 7)}</span>
            <span class="text-[var(--gl-border)]">·</span>
            <a
              href={@github_url}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1.5 text-[var(--gl-text-muted)] hover:text-[var(--gl-accent)] transition-colors"
            >
              <svg
                viewBox="0 0 16 16"
                fill="currentColor"
                class="w-4 h-4"
                aria-hidden="true"
              >
                <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
              </svg>
              {@github_label}
            </a>
          </div>
          <h1 class="text-3xl font-bold text-white uppercase tracking-wider">
            Pipeline
          </h1>
        </div>

        <div class="nb-card-muted p-1">
          <.svelte
            name="DagViewer"
            props={
              %{
                nodes: @nodes,
                edges: @edges,
                workflow_runs: @workflow_runs,
                pipeline_label: String.slice(@sha, 0, 7),
                pipeline_sublabel: "#{@owner}/#{@repo}"
              }
            }
            socket={@socket}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
