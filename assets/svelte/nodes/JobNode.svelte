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
