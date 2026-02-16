# Expandable Workflow Jobs Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow workflow nodes in the DAG viewer to expand inline to reveal their child job nodes, replacing the separate "jobs" drill-down view.

**Architecture:** The poller already fetches jobs for each workflow run. We'll pass serialized workflow run data (with jobs) to the Svelte component as a new prop. The DagViewer manages expand/collapse state client-side, dynamically building job nodes/edges and merging them into the Dagre layout. No new API calls or routes needed.

**Tech Stack:** Elixir/Phoenix LiveView, Svelte 5 (runes), @xyflow/svelte, dagre

---

### Task 1: Add `workflow_runs` serialization to WorkflowGraph

The poller broadcasts `%{nodes, edges}` but we also need the raw workflow run data (with jobs) sent to the client for client-side job node building.

**Files:**
- Modify: `lib/greenlight/github/workflow_graph.ex`
- Modify: `test/greenlight/github/workflow_graph_test.exs`

**Step 1: Add `serialize_workflow_runs/1` to WorkflowGraph**

This function converts workflow runs (with jobs) into a JSON-serializable list. Each entry includes the run ID and a list of serialized jobs with their `needs` dependencies.

In `lib/greenlight/github/workflow_graph.ex`, add at the bottom of the module (before the final `end`):

```elixir
def serialize_workflow_runs(workflow_runs) do
  Enum.map(workflow_runs, fn run ->
    %{
      id: run.id,
      jobs: Enum.map(run.jobs, fn job ->
        steps_completed = Enum.count(job.steps, &(&1.status == :completed))
        steps_total = length(job.steps)

        elapsed =
          if job.started_at do
            end_time = job.completed_at || DateTime.utc_now()
            DateTime.diff(end_time, job.started_at, :second)
          else
            0
          end

        %{
          id: job.id,
          name: job.name,
          status: to_string(job.status),
          conclusion: job.conclusion && to_string(job.conclusion),
          elapsed: elapsed,
          current_step: job.current_step,
          steps_completed: steps_completed,
          steps_total: steps_total,
          html_url: job.html_url,
          needs: job.needs || []
        }
      end)
    }
  end)
end
```

**Step 2: Add a test for `serialize_workflow_runs/1`**

In `test/greenlight/github/workflow_graph_test.exs`, add a new describe block:

```elixir
describe "serialize_workflow_runs/1" do
  test "serializes workflow runs with job data for client" do
    runs = [
      %Models.WorkflowRun{
        id: 1,
        name: "CI",
        workflow_id: 10,
        status: :completed,
        conclusion: :success,
        head_sha: "abc",
        event: "push",
        html_url: "https://github.com/o/r/actions/runs/1",
        created_at: ~U[2026-02-12 10:00:00Z],
        updated_at: ~U[2026-02-12 10:05:00Z],
        jobs: [
          %Models.Job{
            id: 100,
            name: "build",
            status: :completed,
            conclusion: :success,
            html_url: "https://github.com/o/r/actions/runs/1/job/100",
            started_at: ~U[2026-02-12 10:00:00Z],
            completed_at: ~U[2026-02-12 10:02:00Z],
            steps: [],
            needs: []
          },
          %Models.Job{
            id: 101,
            name: "test",
            status: :completed,
            conclusion: :success,
            html_url: "https://github.com/o/r/actions/runs/1/job/101",
            started_at: ~U[2026-02-12 10:02:00Z],
            completed_at: ~U[2026-02-12 10:04:00Z],
            steps: [
              %Models.Step{name: "Checkout", status: :completed, conclusion: :success, number: 1}
            ],
            needs: ["build"]
          }
        ]
      }
    ]

    [serialized] = WorkflowGraph.serialize_workflow_runs(runs)

    assert serialized.id == 1
    assert length(serialized.jobs) == 2

    test_job = Enum.find(serialized.jobs, &(&1.name == "test"))
    assert test_job.needs == ["build"]
    assert test_job.steps_completed == 1
    assert test_job.steps_total == 1
    assert test_job.status == "completed"
  end
end
```

**Step 3: Run tests**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix test test/greenlight/github/workflow_graph_test.exs -v`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add lib/greenlight/github/workflow_graph.ex test/greenlight/github/workflow_graph_test.exs
git commit -m "feat: add serialize_workflow_runs for client-side job expansion"
```

---

### Task 2: Include workflow_runs in poller broadcast

The poller currently broadcasts `%{nodes: nodes, edges: edges}`. Add `workflow_runs` to this payload so the LiveView can pass it to the Svelte component.

**Files:**
- Modify: `lib/greenlight/github/poller.ex` (lines 90-108, the `do_poll/1` function)

**Step 1: Update `do_poll/1` to include serialized workflow runs**

Replace the `do_poll/1` function body. Change `graph_data = WorkflowGraph.build_workflow_dag(runs_with_jobs)` to also include `workflow_runs`:

In `lib/greenlight/github/poller.ex`, replace `do_poll/1`:

```elixir
defp do_poll(state) do
  topic = "pipeline:#{state.owner}/#{state.repo}:#{state.ref}"

  with {:ok, runs} <- Client.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
       runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do
    %{nodes: nodes, edges: edges} = WorkflowGraph.build_workflow_dag(runs_with_jobs)
    workflow_runs = WorkflowGraph.serialize_workflow_runs(runs_with_jobs)

    graph_data = %{nodes: nodes, edges: edges, workflow_runs: workflow_runs}

    if graph_data != state.last_state do
      Phoenix.PubSub.broadcast(
        Greenlight.PubSub,
        topic,
        {:pipeline_update, graph_data}
      )
    end

    %{state | last_state: graph_data, poll_interval: compute_interval(runs_with_jobs)}
  else
    {:error, _reason} ->
      state
  end
end
```

**Step 2: Run existing tests to verify no breakage**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix test -v`
Expected: All tests pass.

**Step 3: Commit**

```bash
git add lib/greenlight/github/poller.ex
git commit -m "feat: include workflow_runs in poller broadcast"
```

---

### Task 3: Simplify PipelineLive to pass workflow_runs

Remove the separate "jobs" view mode. Pass `workflow_runs` to the Svelte component. Remove `node_clicked` and `back_clicked` event handlers (expansion happens client-side).

**Files:**
- Modify: `lib/greenlight_web/live/pipeline_live.ex`

**Step 1: Simplify assigns and remove view_level**

Replace the entire `pipeline_live.ex` with:

```elixir
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
    {:noreply,
     assign(socket, nodes: nodes, edges: edges, workflow_runs: workflow_runs)}
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
```

**Step 2: Run tests**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix test -v`
Expected: All tests pass (the LiveView isn't directly tested beyond compilation).

**Step 3: Commit**

```bash
git add lib/greenlight_web/live/pipeline_live.ex
git commit -m "feat: simplify PipelineLive to pass workflow_runs for inline expansion"
```

---

### Task 4: Update DagViewer.svelte for expandable workflows

This is the core change. The DagViewer receives `workflow_runs` and manages expand/collapse state. When a workflow is expanded, it builds job nodes/edges client-side and merges them into the Dagre layout.

**Files:**
- Modify: `assets/svelte/DagViewer.svelte`

**Step 1: Rewrite DagViewer.svelte**

Replace the entire file:

```svelte
<script>
  import { SvelteFlow, Background, Controls, MiniMap } from '@xyflow/svelte';
  import dagre from 'dagre';
  import WorkflowNode from './nodes/WorkflowNode.svelte';
  import JobNode from './nodes/JobNode.svelte';
  import PipelineNode from './nodes/PipelineNode.svelte';
  import FitViewHelper from './FitViewHelper.svelte';

  let { nodes = [], edges = [], workflow_runs = [], pipeline_label = "", pipeline_sublabel = "" } = $props();

  const nodeTypes = {
    workflow: WorkflowNode,
    job: JobNode,
    pipeline: PipelineNode
  };

  let expandedWorkflows = $state(new Set());

  function toggleWorkflow(runId) {
    const next = new Set(expandedWorkflows);
    if (next.has(runId)) {
      next.delete(runId);
    } else {
      next.add(runId);
    }
    expandedWorkflows = next;
  }

  function buildJobNodesAndEdges(workflowRun) {
    const wfNodeId = `wf-${workflowRun.id}`;
    const jobs = workflowRun.jobs || [];

    // Build name -> node ID lookup for resolving needs
    const nameToId = {};
    jobs.forEach(job => {
      nameToId[job.name] = `job-${workflowRun.id}-${job.id}`;
    });

    const jobNodes = jobs.map(job => ({
      id: `job-${workflowRun.id}-${job.id}`,
      type: 'job',
      position: { x: 0, y: 0 },
      data: {
        name: job.name,
        status: job.status,
        conclusion: job.conclusion,
        elapsed: job.elapsed,
        current_step: job.current_step,
        steps_completed: job.steps_completed,
        steps_total: job.steps_total,
        html_url: job.html_url
      }
    }));

    // Edges: job dependencies from `needs`
    const jobEdges = [];
    jobs.forEach(job => {
      const targetId = nameToId[job.name];
      if (job.needs && job.needs.length > 0) {
        job.needs.forEach(neededName => {
          const sourceId = nameToId[neededName];
          if (sourceId) {
            jobEdges.push({
              id: `e-${sourceId}-${targetId}`,
              source: sourceId,
              target: targetId,
              animated: job.status === 'in_progress',
              data: { type: 'job-dep' }
            });
          }
        });
      }
    });

    // Connector edges: workflow -> root jobs (jobs with no needs or needs outside this workflow)
    const rootJobs = jobs.filter(job => !job.needs || job.needs.length === 0 ||
      job.needs.every(n => !nameToId[n]));
    const connectorEdges = rootJobs.map(job => ({
      id: `e-${wfNodeId}-job-${workflowRun.id}-${job.id}`,
      source: wfNodeId,
      target: `job-${workflowRun.id}-${job.id}`,
      animated: job.status === 'in_progress',
      data: { type: 'wf-job-connector' }
    }));

    return {
      nodes: jobNodes,
      edges: [...connectorEdges, ...jobEdges]
    };
  }

  // Mark workflow nodes with expanded state
  const workflowNodesWithExpanded = $derived(
    nodes.map(n => {
      if (n.type === 'workflow') {
        const runId = parseInt(n.id.replace('wf-', ''));
        return { ...n, data: { ...n.data, expanded: expandedWorkflows.has(runId) } };
      }
      return n;
    })
  );

  // Merge expanded job nodes/edges into the base graph
  const mergedGraph = $derived.by(() => {
    let allNodes = [...workflowNodesWithExpanded];
    let allEdges = [...edges];

    for (const runId of expandedWorkflows) {
      const wfRun = workflow_runs.find(r => r.id === runId);
      if (wfRun) {
        const { nodes: jobNodes, edges: jobEdges } = buildJobNodesAndEdges(wfRun);
        allNodes = [...allNodes, ...jobNodes];
        allEdges = [...allEdges, ...jobEdges];
      }
    }

    return { nodes: allNodes, edges: allEdges };
  });

  function addRootNode(inputNodes, inputEdges) {
    if (inputNodes.length === 0) return { nodes: inputNodes, edges: inputEdges };

    const rootNode = {
      id: 'pipeline-root',
      type: 'pipeline',
      position: { x: 0, y: 0 },
      data: { label: pipeline_label, sublabel: pipeline_sublabel }
    };

    // Find nodes with no incoming edges — these connect to the root
    const targetIds = new Set(inputEdges.map(e => e.target));
    const parentless = inputNodes.filter(n => !targetIds.has(n.id));

    const rootEdges = parentless.map(n => ({
      id: `e-root-${n.id}`,
      source: 'pipeline-root',
      target: n.id,
      animated: false
    }));

    return {
      nodes: [rootNode, ...inputNodes],
      edges: [...rootEdges, ...inputEdges]
    };
  }

  function getLayoutedElements(inputNodes, inputEdges, direction = 'LR') {
    const g = new dagre.graphlib.Graph();
    g.setDefaultEdgeLabel(() => ({}));
    g.setGraph({ rankdir: direction, nodesep: 30, ranksep: 100 });

    const nodeWidth = (node) => {
      if (node.type === 'pipeline') return 180;
      if (node.type === 'job') return 220;
      return 240;
    };
    const nodeHeight = (node) => {
      if (node.type === 'pipeline') return 70;
      if (node.type === 'job') return 100;
      return 110;
    };

    inputNodes.forEach(node => {
      g.setNode(node.id, { width: nodeWidth(node), height: nodeHeight(node) });
    });

    inputEdges.forEach(edge => {
      g.setEdge(edge.source, edge.target);
    });

    dagre.layout(g);

    return inputNodes.map(node => {
      const pos = g.node(node.id);
      const w = nodeWidth(node);
      const h = nodeHeight(node);
      return {
        ...node,
        position: {
          x: pos.x - w / 2,
          y: pos.y - h / 2
        },
        width: w,
        height: h,
        style: `width: ${w}px; max-width: ${w}px;`
      };
    });
  }

  const withRoot = $derived(addRootNode(mergedGraph.nodes, mergedGraph.edges));
  const layoutedNodes = $derived(getLayoutedElements(withRoot.nodes, withRoot.edges));

  const styledEdges = $derived(withRoot.edges.map(edge => {
    const isConnector = edge.data?.type === 'wf-job-connector';
    const isJobDep = edge.data?.type === 'job-dep';

    let style = `stroke: var(--gl-border-strong); stroke-width: 2px;`;
    if (isConnector) {
      style = `stroke: var(--gl-accent); stroke-width: 2px; stroke-dasharray: 6 3;`;
    } else if (isJobDep) {
      style = `stroke: var(--gl-border-strong); stroke-width: 1.5px;`;
    }

    return {
      ...edge,
      style,
      animated: edge.animated || false
    };
  }));

  function handleNodeClick(event) {
    const node = event.detail.node;
    if (node.type === 'workflow') {
      const runId = parseInt(node.id.replace('wf-', ''));
      toggleWorkflow(runId);
    } else if (node.type === 'job' && node.data.html_url) {
      window.open(node.data.html_url, '_blank');
    }
  }
</script>

<div class="w-full h-[calc(100vh-200px)] min-h-[400px] relative overflow-hidden" style="background: var(--gl-bg-primary);">
  <SvelteFlow
    nodes={layoutedNodes}
    edges={styledEdges}
    {nodeTypes}
    fitView
    fitViewOptions={{ padding: 0.05 }}
    onnodeclick={handleNodeClick}
    nodesDraggable={false}
    nodesConnectable={false}
    elementsSelectable={true}
    defaultEdgeOptions={{ type: 'smoothstep' }}
    colorMode="dark"
  >
    <FitViewHelper nodeCount={layoutedNodes.length} />
    <Background bgColor="var(--gl-bg-primary)" gap={20} color="var(--gl-border)" />
    <Controls />
    <MiniMap
      maskColor="rgba(0, 0, 0, 0.7)"
      bgColor="var(--gl-bg-surface)"
      nodeColor="var(--gl-border-strong)"
    />
  </SvelteFlow>
</div>

<style>
  :global(.svelte-flow) {
    background-color: var(--gl-bg-primary) !important;
    --xy-background-color: var(--gl-bg-primary) !important;
    --xy-node-background-color: transparent !important;
    --xy-node-border-radius: 0 !important;
    --xy-edge-stroke: var(--gl-border-strong) !important;
    --xy-edge-stroke-width: 2px !important;
    --xy-minimap-background-color: var(--gl-bg-surface) !important;
    --xy-controls-button-background-color: var(--gl-bg-raised) !important;
    --xy-controls-button-color: var(--gl-text-body) !important;
    --xy-controls-button-border-color: var(--gl-border) !important;
  }
  :global(.svelte-flow .svelte-flow__controls button) {
    border: 2px solid var(--gl-border) !important;
    border-radius: 0 !important;
  }
  :global(.svelte-flow .svelte-flow__controls button:hover) {
    background: var(--gl-bg-surface) !important;
    border-color: var(--gl-accent) !important;
  }
  :global(.svelte-flow .svelte-flow__minimap) {
    border: 2px solid var(--gl-border) !important;
    border-radius: 0 !important;
  }
  :global(.svelte-flow .svelte-flow__edge-path) {
    stroke: var(--gl-border-strong) !important;
    stroke-width: 2px !important;
  }
</style>
```

**Step 2: Verify it compiles**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix assets.build 2>&1 || echo "Check esbuild/tailwind output"`
Expected: No compilation errors.

**Step 3: Commit**

```bash
git add assets/svelte/DagViewer.svelte
git commit -m "feat: add expandable workflow jobs to DagViewer"
```

---

### Task 5: Update WorkflowNode.svelte with expanded indicator

Add a visual chevron indicator showing expand/collapse state. The `expanded` boolean is now passed via `data.expanded` from the DagViewer.

**Files:**
- Modify: `assets/svelte/nodes/WorkflowNode.svelte`

**Step 1: Update WorkflowNode.svelte**

Replace the entire file:

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';

  let { data } = $props();

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }

  const borderColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );

  const shadowColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );
</script>

<Handle type="target" position={Position.Left} />

<div
  class="px-4 py-3 w-[240px] cursor-pointer transition-all duration-150 hover:-translate-x-0.5 hover:-translate-y-0.5"
  style="background: var(--gl-bg-raised); border: 2px solid {borderColor}; border-left: 4px solid {borderColor}; box-shadow: 3px 3px 0px {shadowColor}; font-family: var(--gl-font-mono);"
>
  <div class="flex items-center justify-between gap-2 mb-2">
    <span class="font-bold text-sm truncate text-white">{data.name}</span>
    <div class="flex items-center gap-1">
      <button onclick={openGitHub} class="opacity-40 hover:opacity-100 transition-opacity text-[var(--gl-accent)]" title="View on GitHub">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </button>
      <span
        class="text-xs transition-transform duration-200 text-[var(--gl-text-muted)]"
        style="display: inline-block; transform: rotate({data.expanded ? '90deg' : '0deg'});"
      >
        &#9656;
      </span>
    </div>
  </div>
  <div class="flex items-center justify-between gap-3">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-[var(--gl-text-muted)]">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.jobs_total > 0}
    <div class="text-xs text-[var(--gl-text-muted)] mt-2">
      {data.jobs_passed}/{data.jobs_total} jobs
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Right} />
```

**Step 2: Commit**

```bash
git add assets/svelte/nodes/WorkflowNode.svelte
git commit -m "feat: add expand/collapse chevron to WorkflowNode"
```

---

### Task 6: Update JobNode.svelte with click-to-GitHub and reduced shadow

Make the job node body clickable (opens GitHub URL) and reduce the shadow to 2px for visual hierarchy.

**Files:**
- Modify: `assets/svelte/nodes/JobNode.svelte`

**Step 1: Update JobNode.svelte**

Replace the entire file:

```svelte
<script>
  import { Handle, Position } from '@xyflow/svelte';
  import StatusBadge from '../components/StatusBadge.svelte';
  import ProgressBar from '../components/ProgressBar.svelte';

  let { data } = $props();

  function formatElapsed(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  }

  const borderColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );

  const shadowColor = $derived(
    data.conclusion === 'failure' ? 'var(--gl-status-error)' :
    data.status === 'in_progress' ? 'var(--gl-status-warning)' :
    data.conclusion === 'success' ? 'var(--gl-status-success)' :
    'var(--gl-border)'
  );
</script>

<Handle type="target" position={Position.Left} />

<div
  class="px-3 py-2 w-[220px] cursor-pointer transition-all duration-150 hover:-translate-x-0.5 hover:-translate-y-0.5"
  style="background: var(--gl-bg-raised); border: 2px solid {borderColor}; border-left: 4px solid {borderColor}; box-shadow: 2px 2px 0px {shadowColor}; font-family: var(--gl-font-mono);"
>
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-bold text-xs truncate text-white">{data.name}</span>
    {#if data.html_url}
      <span class="text-xs text-[var(--gl-text-muted)]" title="Click to view on GitHub">
        <svg class="w-3.5 h-3.5 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </span>
    {/if}
  </div>
  <div class="flex items-center justify-between gap-2">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-[var(--gl-text-muted)]">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.current_step}
    <div class="text-xs text-[var(--gl-status-warning)] mt-1 truncate" title={data.current_step}>
      &triangleright; {data.current_step}
    </div>
  {/if}
  {#if data.steps_total > 0}
    <div class="mt-1.5">
      <ProgressBar completed={data.steps_completed} total={data.steps_total} />
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Right} />
```

**Step 2: Commit**

```bash
git add assets/svelte/nodes/JobNode.svelte
git commit -m "feat: add click-to-GitHub and reduce shadow on JobNode"
```

---

### Task 7: Manual verification

**Step 1: Start the dev server**

Run: `cd /home/jordangarrison/dev/jordangarrison/greenlight && mix phx.server`

**Step 2: Verify the following in the browser**

1. Navigate to a pipeline view (e.g., click a commit from a repo page)
2. Workflow nodes display with a small chevron indicator (pointing right)
3. Click a workflow node — its jobs should appear branching to the right
4. The chevron rotates 90 degrees on the expanded workflow
5. Dashed connector edges (cyan) link the workflow to its root jobs
6. Job-to-job dependency edges are solid and slightly thinner
7. Click a job node — should open GitHub Actions job URL in a new tab
8. Click the workflow node again — jobs collapse and layout re-adjusts
9. Expand multiple workflows simultaneously — all render correctly
10. The GitHub link button on workflow nodes still works independently

**Step 3: Final commit if any tweaks needed**
