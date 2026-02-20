defmodule Greenlight.WideEvent do
  @moduledoc """
  Wide event logging module for structured, context-rich log events.

  Accumulates context into the process's Logger metadata throughout the
  lifecycle of a request, poll cycle, or LiveView session, then emits a
  single structured event containing all accumulated context.

  ## Usage

      # Accumulate context
      WideEvent.add(owner: "myorg", repo: "myrepo")
      WideEvent.add(status: 200)

      # Emit a single wide event (includes all accumulated metadata)
      WideEvent.emit("github.api_call", duration_ms: 142)

      # Or wrap a function for automatic timing and error capture
      WideEvent.with_context("poller.poll_cycle", level: :debug, fn ->
        WideEvent.add(workflow_runs: 5)
        do_work()
      end)
  """

  require Logger

  @doc """
  Accumulate context into the process's wide event metadata.

  Accepts a keyword list or map. Keys are merged with existing metadata.
  """
  def add(fields) when is_list(fields) do
    Logger.metadata(fields)
  end

  def add(fields) when is_map(fields) do
    Logger.metadata(Map.to_list(fields))
  end

  @doc """
  Emit a wide event with accumulated metadata plus extra fields.

  The event name is included as the `event` key in the structured log.

  ## Options

    * `:level` - Log level, defaults to `:info`
  """
  def emit(event_name, extra \\ [], opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    report = Keyword.put(extra, :event, event_name)
    Logger.log(level, report)
  end

  @doc """
  Execute a function with automatic timing and error capture.

  Emits a wide event in an `after` block so it always fires, even on crash.
  Sets `outcome` to `:success` or `:error` and includes `duration_ms`.

  ## Options

    * `:level` - Log level, defaults to `:info`
  """
  def with_context(event_name, opts \\ [], fun) when is_function(fun, 0) do
    level = Keyword.get(opts, :level, :info)
    start = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      add(outcome: :success)
      result
    rescue
      error ->
        add(
          outcome: :error,
          error_type: inspect(error.__struct__),
          error_message: Exception.message(error)
        )

        reraise error, __STACKTRACE__
    after
      duration_ms = System.monotonic_time(:millisecond) - start
      emit(event_name, [duration_ms: duration_ms], level: level)
    end
  end
end
