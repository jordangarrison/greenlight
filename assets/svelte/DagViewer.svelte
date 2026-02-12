<script>
  import { SvelteFlow, Background, Controls, MiniMap } from '@xyflow/svelte';
  import dagre from 'dagre';
  import WorkflowNode from './nodes/WorkflowNode.svelte';
  import JobNode from './nodes/JobNode.svelte';
  import '@xyflow/svelte/dist/style.css';

  let { nodes = [], edges = [], view_level = "workflows", live } = $props();

  const nodeTypes = {
    workflow: WorkflowNode,
    job: JobNode
  };

  function getLayoutedElements(inputNodes, inputEdges, direction = 'TB') {
    const g = new dagre.graphlib.Graph();
    g.setDefaultEdgeLabel(() => ({}));
    g.setGraph({ rankdir: direction, nodesep: 50, ranksep: 80 });

    const nodeWidth = view_level === 'workflows' ? 220 : 200;
    const nodeHeight = view_level === 'workflows' ? 100 : 90;

    inputNodes.forEach(node => {
      g.setNode(node.id, { width: nodeWidth, height: nodeHeight });
    });

    inputEdges.forEach(edge => {
      g.setEdge(edge.source, edge.target);
    });

    dagre.layout(g);

    return inputNodes.map(node => {
      const pos = g.node(node.id);
      return {
        ...node,
        position: {
          x: pos.x - nodeWidth / 2,
          y: pos.y - nodeHeight / 2
        }
      };
    });
  }

  const layoutedNodes = $derived(getLayoutedElements(nodes, edges));

  function handleNodeClick(event) {
    const node = event.detail.node;
    if (view_level === 'workflows' && node.type === 'workflow') {
      live.pushEvent("node_clicked", { workflow_run_id: parseInt(node.id.replace("wf-", "")) });
    }
  }

  function handleBackClick() {
    live.pushEvent("back_clicked", {});
  }
</script>

<div class="w-full h-[600px] relative">
  {#if view_level === 'jobs'}
    <button
      onclick={handleBackClick}
      class="absolute top-3 left-3 z-10 px-3 py-1.5 text-sm bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors flex items-center gap-1.5"
    >
      ← Back to workflows
    </button>
  {/if}

  <SvelteFlow
    nodes={layoutedNodes}
    {edges}
    {nodeTypes}
    fitView
    onnodeclick={handleNodeClick}
    nodesDraggable={false}
    nodesConnectable={false}
    elementsSelectable={true}
    defaultEdgeOptions={{ type: 'smoothstep' }}
  >
    <Background />
    <Controls />
    <MiniMap />
  </SvelteFlow>
</div>
