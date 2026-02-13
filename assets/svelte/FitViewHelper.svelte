<script>
  import { useSvelteFlow } from '@xyflow/svelte';

  let { nodeCount = 0 } = $props();
  const { fitView } = useSvelteFlow();

  $effect(() => {
    if (nodeCount > 0) {
      setTimeout(() => fitView({ padding: 0.05, duration: 200 }), 50);
    }
  });
</script>
