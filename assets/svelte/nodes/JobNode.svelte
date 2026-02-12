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

  function openGitHub(e) {
    e.stopPropagation();
    window.open(data.html_url, '_blank');
  }
</script>

<Handle type="target" position={Position.Top} />

<div class="px-3 py-2 rounded-lg border bg-white dark:bg-gray-800 shadow-sm min-w-[180px]
  {data.conclusion === 'failure' ? 'border-red-300' : data.status === 'in_progress' ? 'border-amber-300' : data.conclusion === 'success' ? 'border-green-300' : 'border-gray-200'}">
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-medium text-xs truncate">{data.name}</span>
    <button onclick={openGitHub} class="text-gray-400 hover:text-blue-500 transition-colors" title="View on GitHub">
      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-2">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-gray-500">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.current_step}
    <div class="text-xs text-amber-600 dark:text-amber-400 mt-1 truncate" title={data.current_step}>
      ▸ {data.current_step}
    </div>
  {/if}
  {#if data.steps_total > 0}
    <div class="mt-1.5">
      <ProgressBar completed={data.steps_completed} total={data.steps_total} />
    </div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
