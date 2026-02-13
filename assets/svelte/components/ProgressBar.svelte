<script>
  let { completed = 0, total = 0 } = $props()

  const percent = $derived(total > 0 ? Math.round((completed / total) * 100) : 0)
</script>

<div class="w-full h-2 border border-[var(--gl-border)]" style="background: var(--gl-bg-primary);">
  <div
    class="h-full transition-all duration-500"
    style="width: {percent}%; background: {percent === 100 ? 'var(--gl-status-success)' : 'var(--gl-status-warning)'};"
  ></div>
</div>
