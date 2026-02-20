# Wide Event Logging Design

## Overview

Implement structured wide event logging for Greenlight following the canonical log line pattern. Each logical unit of work (HTTP request, poll cycle, API call) emits a single context-rich JSON event containing everything needed to diagnose issues.

## Goals

- One structured JSON log event per logical operation
- High cardinality fields (request IDs, user sessions, repo identifiers)
- Business context in every event (repos watched, workflow states, rate limits)
- Environment context (app version, git SHA, node, env)
- Debug-level for routine operations, info-level for significant events and errors
- Zero changes to existing business logic patterns — logging is infrastructure

## Dependencies

Add to `mix.exs`:

```elixir
{:logger_json, "~> 7.0"}
```

No other new dependencies. Uses built-in `Logger`, `Logger.metadata/1`, and `:telemetry`.

## Architecture

### Core Module: `Greenlight.WideEvent`

A thin wrapper around `Logger.metadata/1` providing three functions:

- **`add/1`** — Merges key-value pairs into process-scoped Logger metadata. Call throughout code to accumulate context.
- **`emit/2`** — Takes an event name and optional extra fields, merges with accumulated metadata, emits a single structured Logger report. Accepts a `:level` option (defaults to `:info`).
- **`with_context/3`** — Wraps a function with automatic timing and error capture. Calls `emit` in an `after` block so the event always fires. Accepts event name, options, and a zero-arity function.

```elixir
defmodule Greenlight.WideEvent do
  require Logger

  @doc "Accumulate context into the process's wide event metadata."
  def add(fields) when is_list(fields) do
    Logger.metadata(fields)
  end

  def add(fields) when is_map(fields) do
    Logger.metadata(Map.to_list(fields))
  end

  @doc "Emit a wide event with accumulated metadata plus extra fields."
  def emit(event_name, extra \\ [], opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    report = Keyword.merge(extra, event: event_name)
    Logger.log(level, fn -> {"%{event}", report} end)
  end

  @doc "Execute a function with automatic timing and error capture."
  def with_context(event_name, opts \\ [], fun) when is_function(fun, 0) do
    level = Keyword.get(opts, :level, :info)
    start = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      add(outcome: :success)
      result
    rescue
      error ->
        add(outcome: :error, error_type: error.__struct__, error_message: Exception.message(error))
        reraise error, __STACKTRACE__
    after
      duration_ms = System.monotonic_time(:millisecond) - start
      emit(event_name, [duration_ms: duration_ms], level: level)
    end
  end
end
```

### Integration 1: Req Plugin for GitHub API Calls

A Req plugin (`Greenlight.GitHub.ReqLogger`) that hooks into every GitHub API request automatically.

**Registered in** `Greenlight.GitHub.Client.new_client/0` as part of the Req pipeline.

**Captures per API call:**
- `github.endpoint` — the API path (e.g., `/repos/{owner}/{repo}/actions/runs`)
- `github.method` — HTTP method
- `github.status` — response status code
- `github.duration_ms` — request duration
- `github.response_size` — response body byte size
- `github.rate_limit_remaining` — from `x-ratelimit-remaining` header
- `github.rate_limit_reset` — from `x-ratelimit-reset` header

**Log levels:**
- `:debug` for successful 2xx responses
- `:info` for rate limit warnings (remaining < 100)
- `:error` for 4xx/5xx responses and connection errors

```elixir
defmodule Greenlight.GitHub.ReqLogger do
  require Logger

  def attach(%Req.Request{} = request) do
    request
    |> Req.Request.register_options([:wide_event_context])
    |> Req.Request.append_request_steps(wide_event_start: &start_step/1)
    |> Req.Request.append_response_steps(wide_event_stop: &stop_step/1)
    |> Req.Request.append_error_steps(wide_event_error: &error_step/1)
  end

  defp start_step(request) do
    request
    |> Req.Request.put_private(:wide_event_start, System.monotonic_time(:millisecond))
  end

  defp stop_step({request, response}) do
    start = Req.Request.get_private(request, :wide_event_start)
    duration_ms = System.monotonic_time(:millisecond) - start
    url = request.url

    rate_remaining =
      Req.Response.get_header(response, "x-ratelimit-remaining")
      |> List.first()
      |> parse_int()

    rate_reset =
      Req.Response.get_header(response, "x-ratelimit-reset")
      |> List.first()
      |> parse_int()

    level = cond do
      response.status >= 400 -> :error
      rate_remaining != nil and rate_remaining < 100 -> :info
      true -> :debug
    end

    extra_context = Req.Request.get_private(request, :wide_event_context, [])

    Greenlight.WideEvent.emit("github.api_call",
      Keyword.merge(extra_context, [
        github_endpoint: url.path,
        github_method: request.method,
        github_status: response.status,
        github_duration_ms: duration_ms,
        github_response_size: byte_size(response.body || ""),
        github_rate_limit_remaining: rate_remaining,
        github_rate_limit_reset: rate_reset,
      ]),
      level: level
    )

    {request, response}
  end

  defp error_step({request, exception}) do
    start = Req.Request.get_private(request, :wide_event_start)
    duration_ms = System.monotonic_time(:millisecond) - start
    url = request.url

    Greenlight.WideEvent.emit("github.api_call", [
      github_endpoint: url.path,
      github_method: request.method,
      github_status: :error,
      github_duration_ms: duration_ms,
      github_error: Exception.message(exception),
      github_error_type: exception.__struct__,
    ], level: :error)

    {request, exception}
  end

  defp parse_int(nil), do: nil
  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
end
```

### Integration 2: Poller GenServer

Modify `Greenlight.GitHub.Poller` to emit one wide event per poll cycle.

**In `init/1`** — Set base metadata:

```elixir
Logger.metadata(
  poller_owner: owner,
  poller_repo: repo,
  poller_ref: ref,
  poller_pid: inspect(self())
)
```

**In `do_poll/1`** — Wrap with `WideEvent.with_context/3`:

```elixir
WideEvent.with_context("poller.poll_cycle", level: :debug, fn ->
  WideEvent.add(subscriber_count: count_subscribers())

  # existing poll logic...
  workflow_runs = Client.list_workflow_runs(...)
  WideEvent.add(workflow_runs_count: length(workflow_runs))

  jobs = Client.list_jobs(...)
  WideEvent.add(jobs_count: length(jobs))

  # workflow YAML resolution
  WideEvent.add(workflow_cache_hit: cached?)

  # broadcast update
  WideEvent.add(broadcast_topic: topic)
end)
```

**Level escalation:** If the poll encounters errors (partial failures from API calls), the Req plugin already logs those individually at `:error`. The poll cycle event stays at `:debug` for routine cycles, escalated to `:info` when state changes (new workflow runs or completed jobs detected).

### Integration 3: LiveView Sessions

**In each LiveView `mount/3`:**

```elixir
def mount(params, _session, socket) do
  WideEvent.add(
    live_view: __MODULE__,
    live_view_params: inspect(params),
    connected: connected?(socket)
  )
  WideEvent.emit("liveview.mounted", [], level: :debug)

  # existing mount logic...
end
```

**In `handle_info({:pipeline_update, ...})`:**

```elixir
WideEvent.emit("liveview.pipeline_update", [
  nodes_count: length(nodes),
  edges_count: length(edges),
  workflow_runs_count: length(workflow_runs),
], level: :debug)
```

### Integration 4: HTTP Request Telemetry Handler

A telemetry handler attached to `[:phoenix, :endpoint, :stop]` for initial page loads.

```elixir
defmodule Greenlight.RequestLogger do
  require Logger

  def attach do
    :telemetry.attach(
      "greenlight-request-logger",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  def handle_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    conn = metadata.conn
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Greenlight.WideEvent.emit("http.request", [
      http_method: conn.method,
      http_path: conn.request_path,
      http_status: conn.status,
      http_duration_ms: duration_ms,
      http_remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
    ], level: :info)
  end
end
```

## Configuration

### config/config.exs

```elixir
# JSON structured logging
config :logger, :default_handler,
  formatter: LoggerJSON.Formatters.Basic.new(metadata: :all)

# Suppress default Phoenix request logging (we handle it via telemetry)
config :phoenix, :logger, false
```

### config/dev.exs

```elixir
config :logger, level: :debug
```

### config/prod.exs

```elixir
config :logger, level: :info
```

### config/test.exs

```elixir
config :logger, level: :warning
```

### config/runtime.exs

```elixir
# Allow runtime log level override
if log_level = System.get_env("LOG_LEVEL") do
  config :logger, level: String.to_existing_atom(log_level)
end
```

### application.ex

Set environment context at startup and attach telemetry handler:

```elixir
def start(_type, _args) do
  # Set global environment context for all wide events
  Logger.metadata(
    app_version: to_string(Application.spec(:greenlight, :vsn)),
    node: Node.self(),
    env: Application.get_env(:greenlight, :env, :dev),
    git_sha: Application.get_env(:greenlight, :git_sha, "unknown")
  )

  # Attach HTTP request logger
  Greenlight.RequestLogger.attach()

  children = [
    # existing children...
  ]

  opts = [strategy: :one_for_one, name: Greenlight.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Log Level Strategy

| Event | Level | When visible |
|-------|-------|-------------|
| `github.api_call` (2xx) | `:debug` | Dev only |
| `github.api_call` (rate limit warning) | `:info` | Dev + Prod |
| `github.api_call` (4xx/5xx) | `:error` | Always |
| `poller.poll_cycle` (routine) | `:debug` | Dev only |
| `poller.poll_cycle` (state change) | `:info` | Dev + Prod |
| `liveview.mounted` | `:debug` | Dev only |
| `liveview.pipeline_update` | `:debug` | Dev only |
| `http.request` | `:info` | Dev + Prod |

## Example Output (JSON)

A single GitHub API call event:

```json
{
  "time": "2026-02-19T15:30:00.000Z",
  "level": "debug",
  "msg": "%{event}",
  "metadata": {
    "event": "github.api_call",
    "github_endpoint": "/repos/myorg/myrepo/actions/runs",
    "github_method": "GET",
    "github_status": 200,
    "github_duration_ms": 142,
    "github_response_size": 15234,
    "github_rate_limit_remaining": 4892,
    "github_rate_limit_reset": 1708358400,
    "poller_owner": "myorg",
    "poller_repo": "myrepo",
    "poller_ref": "main",
    "app_version": "0.1.0",
    "node": "greenlight@localhost",
    "env": "dev",
    "git_sha": "abc1234"
  }
}
```

## Files to Create/Modify

### New files:
- `lib/greenlight/wide_event.ex` — Core WideEvent module
- `lib/greenlight/github/req_logger.ex` — Req plugin for API call logging
- `lib/greenlight/request_logger.ex` — Telemetry handler for HTTP requests

### Modified files:
- `mix.exs` — Add `{:logger_json, "~> 7.0"}`
- `config/config.exs` — LoggerJSON formatter, suppress Phoenix logger
- `config/runtime.exs` — LOG_LEVEL env var override
- `lib/greenlight/application.ex` — Set env metadata, attach telemetry handler
- `lib/greenlight/github/client.ex` — Register ReqLogger plugin in `new_client/0`
- `lib/greenlight/github/poller.ex` — Add metadata in init, wrap do_poll with WideEvent
- `lib/greenlight_web/live/dashboard_live.ex` — Add WideEvent on mount
- `lib/greenlight_web/live/repo_live.ex` — Add WideEvent on mount
- `lib/greenlight_web/live/pipeline_live.ex` — Add WideEvent on mount and pipeline_update
