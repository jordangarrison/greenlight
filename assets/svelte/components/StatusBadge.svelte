<script>
  let { status = "queued", conclusion = null } = $props()

  const displayStatus = $derived(conclusion || status)
  const colorClass = $derived({
    queued: "bg-gray-400",
    in_progress: "bg-amber-400 animate-pulse",
    success: "bg-green-500",
    failure: "bg-red-500",
    cancelled: "bg-gray-400",
    skipped: "bg-gray-300"
  }[displayStatus] || "bg-gray-400")
</script>

<span class="inline-flex items-center gap-1.5">
  <span class="w-2.5 h-2.5 rounded-full {colorClass}"></span>
  <span class="text-xs font-medium capitalize {conclusion === 'cancelled' ? 'line-through' : ''}">
    {displayStatus}
  </span>
</span>
