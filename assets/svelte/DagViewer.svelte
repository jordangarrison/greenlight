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
