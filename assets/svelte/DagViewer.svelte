<script>
  import { SvelteFlow, Background, Controls, MiniMap } from '@xyflow/svelte';
  import dagre from 'dagre';
  import WorkflowNode from './nodes/WorkflowNode.svelte';
  import JobNode from './nodes/JobNode.svelte';
  import PipelineNode from './nodes/PipelineNode.svelte';
  import FitViewHelper from './FitViewHelper.svelte';


  let { nodes = [], edges = [], view_level = "workflows", pipeline_label = "", pipeline_sublabel = "", live } = $props();

  const nodeTypes = {
    workflow: WorkflowNode,
    job: JobNode,
    pipeline: PipelineNode
  };

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
      return view_level === 'workflows' ? 240 : 220;
    };
    const nodeHeight = (node) => {
      if (node.type === 'pipeline') return 70;
      return view_level === 'workflows' ? 110 : 100;
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

  const withRoot = $derived(addRootNode(nodes, edges));
  const layoutedNodes = $derived(getLayoutedElements(withRoot.nodes, withRoot.edges));

  const styledEdges = $derived(withRoot.edges.map(edge => ({
    ...edge,
    style: `stroke: var(--gl-border-strong); stroke-width: 2px;`,
    animated: edge.animated || false
  })));

  function handleNodeClick(event) {
    const node = event.detail.node;
    if (view_level === 'workflows' && node.type === 'workflow') {
      live.pushEvent("node_clicked", {
        workflow_run_id: parseInt(node.id.replace("wf-", "")),
        workflow_name: node.data.name
      });
    }
  }

  function handleBackClick() {
    live.pushEvent("back_clicked", {});
  }
</script>

<div class="w-full h-[calc(100vh-200px)] min-h-[400px] relative overflow-hidden" style="background: var(--gl-bg-primary);">
  {#if view_level === 'jobs'}
    <button
      onclick={handleBackClick}
      class="absolute top-3 left-3 z-10 px-4 py-2 text-sm font-bold uppercase tracking-wider nb-btn cursor-pointer"
      style="background: var(--gl-bg-raised); color: var(--gl-accent); border: 2px solid var(--gl-accent); font-family: var(--gl-font-mono);"
    >
      &larr; Workflows
    </button>
  {/if}

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
