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
</script>

<Handle type="target" position={Position.Top} />

<div class="px-4 py-3 rounded-lg border-2 bg-white dark:bg-gray-800 shadow-md min-w-[200px]
  {data.conclusion === 'failure' ? 'border-red-400' : data.status === 'in_progress' ? 'border-amber-400' : data.conclusion === 'success' ? 'border-green-400' : 'border-gray-300'}">
  <div class="flex items-center justify-between gap-2 mb-1">
    <span class="font-semibold text-sm truncate">{data.name}</span>
    <button onclick={openGitHub} class="text-gray-400 hover:text-blue-500 transition-colors" title="View on GitHub">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
      </svg>
    </button>
  </div>
  <div class="flex items-center justify-between gap-3">
    <StatusBadge status={data.status} conclusion={data.conclusion} />
    <span class="text-xs text-gray-500">{formatElapsed(data.elapsed)}</span>
  </div>
  {#if data.jobs_total > 0}
    <div class="text-xs text-gray-500 mt-1">{data.jobs_passed}/{data.jobs_total} jobs passed</div>
  {/if}
</div>

<Handle type="source" position={Position.Bottom} />
