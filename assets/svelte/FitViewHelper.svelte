<script>
  import { useSvelteFlow } from '@xyflow/svelte';

  // fitTrigger is a counter controlled by the parent component.
  // Incremented on initial load and user-initiated actions (expand/collapse).
  // Never incremented by server data updates — preserving viewport on polls.
  let { fitTrigger = 0 } = $props();
  const { fitView } = useSvelteFlow();

  $effect(() => {
    if (fitTrigger > 0) {
      setTimeout(() => fitView({ padding: 0.05, duration: 200 }), 50);
    }
  });
</script>
