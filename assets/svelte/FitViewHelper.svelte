<script>
  import { useSvelteFlow } from '@xyflow/svelte';

  let { nodeCount = 0 } = $props();
  const { fitView } = useSvelteFlow();

  // Only fit view once — when nodes first appear (initial load).
  // After that, preserve the user's viewport on all changes
  // (new workflows, expand/collapse, status updates).
  let hasFitted = false;

  $effect(() => {
    if (nodeCount > 0 && !hasFitted) {
      hasFitted = true;
      setTimeout(() => fitView({ padding: 0.05, duration: 200 }), 50);
    }
  });
</script>
