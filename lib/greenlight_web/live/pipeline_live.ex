defmodule GreenlightWeb.PipelineLive do
  use GreenlightWeb, :live_view

  alias Greenlight.Pollers
  alias Greenlight.GitHub.Client

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
        page_title: "#{owner}/#{repo} - #{String.slice(sha, 0, 7)}"
      )

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
          mount(%{"owner" => owner, "repo" => repo, "sha" => pr.head_sha}, session, socket)
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
          mount(%{"owner" => owner, "repo" => repo, "sha" => run.head_sha}, session, socket)
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
