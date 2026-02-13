<script>
  let { status = "queued", conclusion = null } = $props()

  const displayStatus = $derived(conclusion || status)
  const colorStyles = $derived({
    queued: { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" },
    in_progress: { bg: "var(--gl-status-warning)", text: "var(--gl-bg-primary)" },
    success: { bg: "var(--gl-status-success)", text: "var(--gl-bg-primary)" },
    failure: { bg: "var(--gl-status-error)", text: "var(--gl-bg-primary)" },
    cancelled: { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" },
    skipped: { bg: "var(--gl-border)", text: "var(--gl-text-muted)" }
  }[displayStatus] || { bg: "var(--gl-status-pending)", text: "var(--gl-text-body)" })
</script>

<span
  class="inline-flex items-center gap-1.5 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider border"
  style="background: {colorStyles.bg}; color: {colorStyles.text}; border-color: {colorStyles.bg}; font-family: var(--gl-font-mono);"
  class:animate-pulse={displayStatus === 'in_progress'}
>
  {#if displayStatus === 'cancelled'}
    <span class="line-through">{displayStatus}</span>
  {:else}
    {displayStatus}
  {/if}
</span>
