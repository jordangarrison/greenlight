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
