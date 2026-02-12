<script>
  let { completed = 0, total = 0 } = $props()

  const percent = $derived(total > 0 ? Math.round((completed / total) * 100) : 0)
</script>

<div class="w-full bg-gray-200 rounded-full h-1.5 dark:bg-gray-700">
  <div
    class="h-1.5 rounded-full transition-all duration-500 {percent === 100 ? 'bg-green-500' : 'bg-amber-400'}"
    style="width: {percent}%"
  ></div>
</div>
