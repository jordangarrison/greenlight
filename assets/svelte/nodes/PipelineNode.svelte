<script>
  import { Handle, Position } from '@xyflow/svelte';

  let { data } = $props();
</script>

<Handle type="source" position={Position.Right} />

<div
  class="px-5 py-4 w-[180px] flex flex-col items-center justify-center"
  style="background: var(--gl-bg-raised); border: 3px solid var(--gl-accent); box-shadow: 4px 4px 0px var(--gl-accent); font-family: var(--gl-font-mono);"
>
  <div class="flex items-center gap-2 mb-1">
    <svg class="w-5 h-5 text-[var(--gl-accent)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="4" stroke-width="2" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 2v4m0 12v4m-10-10h4m12 0h4m-3.17-6.83l-2.83 2.83m-5.66 5.66l-2.83 2.83m0-11.32l2.83 2.83m5.66 5.66l2.83 2.83" />
    </svg>
    <span class="font-bold text-sm text-[var(--gl-accent)] uppercase tracking-wider">{data.label}</span>
  </div>
  {#if data.sublabel}
    <span class="text-xs text-[var(--gl-text-muted)]">{data.sublabel}</span>
  {/if}
</div>
