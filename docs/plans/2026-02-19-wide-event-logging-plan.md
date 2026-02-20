# Wide Event Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add structured wide event logging across all layers (GitHub API, Poller, LiveView, HTTP) using LoggerJSON and a custom WideEvent module.

**Architecture:** A thin `Greenlight.WideEvent` module wraps `Logger.metadata/1` to accumulate context per process, then emits a single JSON-structured event per logical operation. A Req plugin handles GitHub API logging automatically. Telemetry handles HTTP request logging. Poller and LiveView emit events directly.

**Tech Stack:** Elixir Logger, LoggerJSON ~> 7.0, :telemetry, Req plugins

**Design doc:** `docs/plans/2026-02-19-wide-event-logging-design.md`

---

### Task 1: Add LoggerJSON dependency and configure JSON logging

**Files:**
- Modify: `mix.exs:42-68` (deps list)
- Modify: `config/config.exs:46-49` (logger config)
- Modify: `config/dev.exs:63-64` (dev logger format)
- Modify: `config/runtime.exs:50` (add LOG_LEVEL override)

**Step 1: Add logger_json to deps in mix.exs**

In `mix.exs`, add `{:logger_json, "~> 7.0"}` to the deps list after the `{:jason, "~> 1.2"}` line:

```elixir
{:jason, "~> 1.2"},
{:logger_json, "~> 7.0"},
```

**Step 2: Replace the default formatter in config/config.exs**

Replace lines 46-49 (the current `config :logger, :default_formatter` block) with:

```elixir
# Structured JSON logging via LoggerJSON
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Basic, metadata: :all}

# Suppress default Phoenix request logging (we handle it via telemetry)
config :phoenix, :logger, false
```

**Step 3: Update config/dev.exs logger config**

Replace line 64 (`config :logger, :default_formatter, format: "[$level] $message\n"`) with:

```elixir
# Show all log levels in development (including debug wide events)
config :logger, level: :debug
```

Note: We remove the dev-specific formatter override so the JSON formatter from config.exs applies everywhere consistently. This makes dev logs the same format as prod, which helps catch formatting issues early.

**Step 4: Add LOG_LEVEL runtime override to config/runtime.exs**

Add this block at the top of `config/runtime.exs`, right after `import Config` (after line 1, before the existing `if System.get_env("PHX_SERVER")` block):

```elixir
# Allow runtime log level override (e.g., LOG_LEVEL=debug in prod)
if log_level = System.get_env("LOG_LEVEL") do
  config :logger, level: String.to_existing_atom(log_level)
end
```

**Step 5: Fetch dependencies**

Run: `mix deps.get`
Expected: `logger_json` downloaded successfully.

**Step 6: Verify compilation**

Run: `mix compile`
Expected: Clean compilation, no warnings.

**Step 7: Commit**

```bash
git add mix.exs mix.lock config/config.exs config/dev.exs config/runtime.exs
git commit -m "feat: add logger_json and configure structured JSON logging"
```

---

### Task 2: Create the WideEvent core module with tests

**Files:**
- Create: `lib/greenlight/wide_event.ex`
- Create: `test/greenlight/wide_event_test.exs`

**Step 1: Write the failing test**

Create `test/greenlight/wide_event_test.exs`:

```elixir
defmodule Greenlight.WideEventTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Greenlight.WideEvent

  setup do
    # Clear any metadata from previous tests
    Logger.metadata([])
    :ok
  end

  describe "add/1" do
    test "adds keyword list to Logger metadata" do
      WideEvent.add(owner: "myorg", repo: "myrepo")
      assert Logger.metadata()[:owner] == "myorg"
      assert Logger.metadata()[:repo] == "myrepo"
    end

    test "adds map to Logger metadata" do
      WideEvent.add(%{owner: "myorg", repo: "myrepo"})
      assert Logger.metadata()[:owner] == "myorg"
      assert Logger.metadata()[:repo] == "myrepo"
    end

    test "merges with existing metadata" do
      WideEvent.add(owner: "myorg")
      WideEvent.add(repo: "myrepo")
      assert Logger.metadata()[:owner] == "myorg"
      assert Logger.metadata()[:repo] == "myrepo"
    end
  end

  describe "emit/3" do
    test "emits a log event with the event name" do
      log =
        capture_log([level: :info], fn ->
          WideEvent.emit("test.event")
        end)

      assert log =~ "test.event"
    end

    test "emits at the specified level" do
      debug_log =
        capture_log([level: :debug], fn ->
          WideEvent.emit("test.debug_event", [], level: :debug)
        end)

      assert debug_log =~ "test.debug_event"
    end

    test "includes extra fields in the log" do
      log =
        capture_log([level: :info], fn ->
          WideEvent.emit("test.event", status: 200, duration_ms: 42)
        end)

      assert log =~ "test.event"
      # The extra fields should be present in the JSON output
      assert log =~ "200" or log =~ "status"
    end
  end

  describe "with_context/3" do
    test "emits an event with duration after the function completes" do
      log =
        capture_log([level: :info], fn ->
          result = WideEvent.with_context("test.timed", fn -> :ok end)
          assert result == :ok
        end)

      assert log =~ "test.timed"
      assert log =~ "duration_ms"
    end

    test "sets outcome to success on normal completion" do
      log =
        capture_log([level: :info], fn ->
          WideEvent.with_context("test.success", fn -> :ok end)
        end)

      assert log =~ "success"
    end

    test "sets outcome to error and reraises on exception" do
      log =
        capture_log([level: :info], fn ->
          assert_raise RuntimeError, "boom", fn ->
            WideEvent.with_context("test.error", fn -> raise "boom" end)
          end
        end)

      assert log =~ "test.error"
      assert log =~ "error"
    end

    test "respects level option" do
      log =
        capture_log([level: :debug], fn ->
          WideEvent.with_context("test.debug", [level: :debug], fn -> :ok end)
        end)

      assert log =~ "test.debug"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/wide_event_test.exs`
Expected: Failures because `Greenlight.WideEvent` doesn't exist yet.

**Step 3: Write the WideEvent module**

Create `lib/greenlight/wide_event.ex`:

```elixir
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
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/greenlight/wide_event_test.exs`
Expected: All tests pass.

**Step 5: Run full test suite to check for regressions**

Run: `mix test`
Expected: All existing tests still pass.

**Step 6: Commit**

```bash
git add lib/greenlight/wide_event.ex test/greenlight/wide_event_test.exs
git commit -m "feat: add WideEvent core module for structured wide event logging"
```

---

### Task 3: Create the Req logger plugin with tests

**Files:**
- Create: `lib/greenlight/github/req_logger.ex`
- Create: `test/greenlight/github/req_logger_test.exs`

**Step 1: Write the failing test**

Create `test/greenlight/github/req_logger_test.exs`:

```elixir
defmodule Greenlight.GitHub.ReqLoggerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Greenlight.GitHub.ReqLogger

  describe "attach/1" do
    test "logs successful API calls at debug level" do
      log =
        capture_log([level: :debug], fn ->
          Req.new(base_url: "https://api.github.com")
          |> ReqLogger.attach()
          |> Req.Request.put_private(:req_test_stub, fn conn ->
            conn
            |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "4999")
            |> Plug.Conn.put_resp_header("x-ratelimit-reset", "1708358400")
            |> Req.Test.json(%{"ok" => true})
          end)
          |> Req.request!(url: "/repos/owner/repo/actions/runs", plug: &Req.Test.passthrough/1)
        end)

      assert log =~ "github.api_call"
      assert log =~ "/repos/owner/repo/actions/runs"
    end

    test "logs error responses at error level" do
      log =
        capture_log([level: :error], fn ->
          Req.new(base_url: "https://api.github.com")
          |> ReqLogger.attach()
          |> Req.request!(
            url: "/repos/owner/repo/actions/runs",
            plug: fn conn ->
              conn
              |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Not Found"}))
            end
          )
        end)

      assert log =~ "github.api_call"
      assert log =~ "404"
    end

    test "logs rate limit warnings at info level" do
      log =
        capture_log([level: :info], fn ->
          Req.new(base_url: "https://api.github.com")
          |> ReqLogger.attach()
          |> Req.request!(
            url: "/repos/owner/repo",
            plug: fn conn ->
              conn
              |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "50")
              |> Plug.Conn.put_resp_header("x-ratelimit-reset", "1708358400")
              |> Req.Test.json(%{"ok" => true})
            end
          )
        end)

      assert log =~ "github.api_call"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/github/req_logger_test.exs`
Expected: Failures because `Greenlight.GitHub.ReqLogger` doesn't exist yet.

**Step 3: Write the ReqLogger plugin**

Create `lib/greenlight/github/req_logger.ex`:

```elixir
defmodule Greenlight.GitHub.ReqLogger do
  @moduledoc """
  Req plugin that emits a wide event for every GitHub API call.

  Captures request/response metadata including endpoint, status, duration,
  response size, and GitHub rate limit headers.

  ## Usage

      Req.new()
      |> ReqLogger.attach()
      |> Req.get!(url: "/repos/owner/repo")

  ## Log Levels

    * `:debug` — successful 2xx responses
    * `:info` — rate limit warnings (remaining < 100)
    * `:error` — 4xx/5xx responses and connection errors
  """

  alias Greenlight.WideEvent

  def attach(%Req.Request{} = request) do
    request
    |> Req.Request.append_request_steps(wide_event_start: &start_step/1)
    |> Req.Request.append_response_steps(wide_event_stop: &stop_step/1)
    |> Req.Request.append_error_steps(wide_event_error: &error_step/1)
  end

  defp start_step(request) do
    Req.Request.put_private(request, :wide_event_start, System.monotonic_time(:millisecond))
  end

  defp stop_step({request, response}) do
    start = Req.Request.get_private(request, :wide_event_start, System.monotonic_time(:millisecond))
    duration_ms = System.monotonic_time(:millisecond) - start

    rate_remaining = get_int_header(response, "x-ratelimit-remaining")
    rate_reset = get_int_header(response, "x-ratelimit-reset")

    level =
      cond do
        response.status >= 400 -> :error
        rate_remaining != nil and rate_remaining < 100 -> :info
        true -> :debug
      end

    body_size =
      case response.body do
        body when is_binary(body) -> byte_size(body)
        body when is_map(body) or is_list(body) -> body |> Jason.encode!() |> byte_size()
        _ -> 0
      end

    WideEvent.emit(
      "github.api_call",
      [
        github_endpoint: URI.to_string(request.url),
        github_method: to_string(request.method),
        github_status: response.status,
        github_duration_ms: duration_ms,
        github_response_size: body_size,
        github_rate_limit_remaining: rate_remaining,
        github_rate_limit_reset: rate_reset
      ],
      level: level
    )

    {request, response}
  end

  defp error_step({request, exception}) do
    start = Req.Request.get_private(request, :wide_event_start, System.monotonic_time(:millisecond))
    duration_ms = System.monotonic_time(:millisecond) - start

    WideEvent.emit(
      "github.api_call",
      [
        github_endpoint: URI.to_string(request.url),
        github_method: to_string(request.method),
        github_status: :error,
        github_duration_ms: duration_ms,
        github_error: Exception.message(exception),
        github_error_type: inspect(exception.__struct__)
      ],
      level: :error
    )

    {request, exception}
  end

  defp get_int_header(response, header_name) do
    case Req.Response.get_header(response, header_name) do
      [value | _] -> parse_int(value)
      _ -> nil
    end
  end

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(_), do: nil
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/greenlight/github/req_logger_test.exs`
Expected: All tests pass.

**Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add lib/greenlight/github/req_logger.ex test/greenlight/github/req_logger_test.exs
git commit -m "feat: add ReqLogger plugin for automatic GitHub API call logging"
```

---

### Task 4: Integrate ReqLogger plugin into the GitHub Client

**Files:**
- Modify: `lib/greenlight/github/client.ex:10-28` (the `new/0` function)

**Step 1: Add the ReqLogger plugin to the Req client**

In `lib/greenlight/github/client.ex`, modify the `new/0` function to pipe through `ReqLogger.attach/1`. Add the alias at the top and modify the function. The final `Req.new(opts)` on line 27 becomes piped through the plugin:

Add alias after line 6:
```elixir
alias Greenlight.GitHub.ReqLogger
```

Replace the `new/0` function body. Change line 27 from `Req.new(opts)` to:

```elixir
Req.new(opts) |> ReqLogger.attach()
```

**Step 2: Run existing client tests to verify no regressions**

Run: `mix test test/greenlight/github/client_test.exs`
Expected: All 7 existing tests pass. Log output may appear at debug level in test output (this is expected since our tests run with level `:warning`, so debug events are filtered out).

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add lib/greenlight/github/client.ex
git commit -m "feat: integrate ReqLogger plugin into GitHub API client"
```

---

### Task 5: Create HTTP request telemetry logger

**Files:**
- Create: `lib/greenlight/request_logger.ex`
- Create: `test/greenlight/request_logger_test.exs`
- Modify: `lib/greenlight/application.ex:9-28` (attach telemetry + set env metadata)

**Step 1: Write the failing test**

Create `test/greenlight/request_logger_test.exs`:

```elixir
defmodule Greenlight.RequestLoggerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Greenlight.RequestLogger

  describe "handle_event/4" do
    test "emits an http.request wide event" do
      # Simulate what Plug.Telemetry sends
      measurements = %{duration: System.convert_time_unit(150, :millisecond, :native)}

      metadata = %{
        conn: %Plug.Conn{
          method: "GET",
          request_path: "/dashboard",
          status: 200,
          remote_ip: {127, 0, 0, 1}
        }
      }

      log =
        capture_log([level: :info], fn ->
          RequestLogger.handle_event(
            [:phoenix, :endpoint, :stop],
            measurements,
            metadata,
            %{}
          )
        end)

      assert log =~ "http.request"
      assert log =~ "GET"
      assert log =~ "/dashboard"
      assert log =~ "200"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/greenlight/request_logger_test.exs`
Expected: Failure because `Greenlight.RequestLogger` doesn't exist yet.

**Step 3: Write the RequestLogger module**

Create `lib/greenlight/request_logger.ex`:

```elixir
defmodule Greenlight.RequestLogger do
  @moduledoc """
  Telemetry handler that emits a wide event for each HTTP request.

  Attaches to `[:phoenix, :endpoint, :stop]` and logs method, path,
  status, duration, and remote IP as a single structured event.
  """

  alias Greenlight.WideEvent

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

    WideEvent.emit(
      "http.request",
      [
        http_method: conn.method,
        http_path: conn.request_path,
        http_status: conn.status,
        http_duration_ms: duration_ms,
        http_remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
      ],
      level: :info
    )
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/greenlight/request_logger_test.exs`
Expected: All tests pass.

**Step 5: Wire up in application.ex**

Modify `lib/greenlight/application.ex`. Add `require Logger` and set environment metadata + attach the telemetry handler at the top of `start/2`:

```elixir
defmodule Greenlight.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Set global environment context for all wide events
    Logger.metadata(
      app_version: to_string(Application.spec(:greenlight, :vsn)),
      node: Node.self(),
      env: Application.get_env(:greenlight, :env, config_env()),
      git_sha: System.get_env("GIT_SHA", "unknown")
    )

    # Attach HTTP request telemetry logger
    Greenlight.RequestLogger.attach()

    children = [
      {NodeJS.Supervisor,
       [
         path: LiveSvelte.SSR.NodeJS.server_path(),
         pool_size: Application.get_env(:greenlight, :ssr_pool_size, 4)
       ]},
      GreenlightWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:greenlight, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Greenlight.PubSub},
      {Registry, keys: :unique, name: Greenlight.PollerRegistry},
      {DynamicSupervisor, name: Greenlight.PollerSupervisor, strategy: :one_for_one},
      GreenlightWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Greenlight.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GreenlightWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp config_env do
    Application.get_env(:greenlight, :env, :dev)
  end
end
```

**Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 7: Commit**

```bash
git add lib/greenlight/request_logger.ex test/greenlight/request_logger_test.exs lib/greenlight/application.ex
git commit -m "feat: add HTTP request telemetry logger and environment metadata"
```

---

### Task 6: Add wide event logging to the Poller GenServer

**Files:**
- Modify: `lib/greenlight/github/poller.ex:1-9` (aliases/requires)
- Modify: `lib/greenlight/github/poller.ex:39-52` (init/1)
- Modify: `lib/greenlight/github/poller.ex:69-73` (handle_info :poll)
- Modify: `lib/greenlight/github/poller.ex:99-133` (do_poll/1)

**Step 1: Add WideEvent alias and require Logger**

At the top of `lib/greenlight/github/poller.ex`, after line 9 (`alias Greenlight.GitHub.{Client, WorkflowGraph}`), add:

```elixir
alias Greenlight.WideEvent
```

**Step 2: Set base metadata in init/1**

In `init/1` (around line 39), after the `state` struct is built (after line 44), add metadata before the `unless` block:

```elixir
Logger.metadata(
  poller_owner: state.owner,
  poller_repo: state.repo,
  poller_ref: state.ref
)
```

This requires adding `require Logger` after the `use GenServer` line.

**Step 3: Add wide event to do_poll/1**

Replace the `do_poll/1` function (lines 99-133) with a version that uses `WideEvent.with_context/3`:

```elixir
defp do_poll(state) do
  WideEvent.with_context("poller.poll_cycle", [level: :debug], fn ->
    topic = "pipeline:#{state.owner}/#{state.repo}:#{state.ref}"
    WideEvent.add(subscriber_count: state.subscriber_count, poll_topic: topic)

    with {:ok, runs} <- Client.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
         runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do
      WideEvent.add(workflow_runs_count: length(runs), jobs_fetched: true)

      {runs_with_needs, workflow_defs} =
        resolve_all_job_needs(
          state.owner,
          state.repo,
          runs_with_jobs,
          Map.get(state, :workflow_defs, %{})
        )

      %{nodes: nodes, edges: edges} = WorkflowGraph.build_workflow_dag(runs_with_needs)
      workflow_runs = WorkflowGraph.serialize_workflow_runs(runs_with_needs)

      graph_data = %{nodes: nodes, edges: edges, workflow_runs: workflow_runs}
      state_changed = graph_data != state.last_state

      WideEvent.add(
        nodes_count: length(nodes),
        edges_count: length(edges),
        state_changed: state_changed
      )

      if state_changed do
        Phoenix.PubSub.broadcast(
          Greenlight.PubSub,
          topic,
          {:pipeline_update, graph_data}
        )
      end

      state
      |> Map.put(:last_state, graph_data)
      |> Map.put(:poll_interval, compute_interval(runs_with_needs))
      |> Map.put(:workflow_defs, workflow_defs)
    else
      {:error, reason} ->
        WideEvent.add(poll_error: inspect(reason))
        state
    end
  end)
end
```

Note: `with_context` returns the result of the function, but `do_poll` is called from `handle_info` which only uses the returned state. The `with_context` wrapping is transparent — it returns whatever the inner function returns (`state`), and emits the wide event in the `after` block.

**Step 4: Run existing poller test**

Run: `mix test test/greenlight/github/poller_test.exs`
Expected: Existing test passes. Debug-level log output may appear but won't affect assertions.

**Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add lib/greenlight/github/poller.ex
git commit -m "feat: add wide event logging to Poller GenServer poll cycles"
```

---

### Task 7: Add wide event logging to LiveView modules

**Files:**
- Modify: `lib/greenlight_web/live/dashboard_live.ex:1-6` (alias)
- Modify: `lib/greenlight_web/live/dashboard_live.ex:7-25` (mount)
- Modify: `lib/greenlight_web/live/repo_live.ex:1-6` (alias)
- Modify: `lib/greenlight_web/live/repo_live.ex:7-26` (mount)
- Modify: `lib/greenlight_web/live/pipeline_live.ex:1-6` (alias)
- Modify: `lib/greenlight_web/live/pipeline_live.ex:8-39` (mount)
- Modify: `lib/greenlight_web/live/pipeline_live.ex:88-93` (handle_info pipeline_update)

**Step 1: Add WideEvent to DashboardLive**

In `lib/greenlight_web/live/dashboard_live.ex`:

Add alias after line 4 (`alias Greenlight.GitHub.Client`):
```elixir
alias Greenlight.WideEvent
```

In `mount/3`, add wide event logging after the existing `socket` assignment (after line 18), before the `if connected?` block:

```elixir
WideEvent.add(
  live_view: "DashboardLive",
  bookmarked_repos_count: length(bookmarked),
  followed_orgs_count: length(orgs),
  connected: connected?(socket)
)
WideEvent.emit("liveview.mounted", [], level: :debug)
```

**Step 2: Add WideEvent to RepoLive**

In `lib/greenlight_web/live/repo_live.ex`:

Add alias after line 4:
```elixir
alias Greenlight.WideEvent
```

In `mount/3`, add wide event logging after the socket assignment (after line 19), before the `if connected?` block:

```elixir
WideEvent.add(
  live_view: "RepoLive",
  repo_owner: owner,
  repo_name: repo,
  connected: connected?(socket)
)
WideEvent.emit("liveview.mounted", [], level: :debug)
```

**Step 3: Add WideEvent to PipelineLive**

In `lib/greenlight_web/live/pipeline_live.ex`:

Add alias after line 5 (`alias Greenlight.GitHub.Client`):
```elixir
alias Greenlight.WideEvent
```

In the first `mount/3` clause (the sha route, line 8), add after the socket assignment (after line 18), before the `if connected?` block:

```elixir
WideEvent.add(
  live_view: "PipelineLive",
  pipeline_owner: owner,
  pipeline_repo: repo,
  pipeline_sha: sha,
  connected: connected?(socket)
)
WideEvent.emit("liveview.mounted", [], level: :debug)
```

In `handle_info` for `:pipeline_update` (around line 88), add before the `{:noreply, ...}` return:

```elixir
WideEvent.emit(
  "liveview.pipeline_update",
  [
    nodes_count: length(nodes),
    edges_count: length(edges),
    workflow_runs_count: length(workflow_runs)
  ],
  level: :debug
)
```

**Step 4: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add lib/greenlight_web/live/dashboard_live.ex lib/greenlight_web/live/repo_live.ex lib/greenlight_web/live/pipeline_live.ex
git commit -m "feat: add wide event logging to LiveView mount and pipeline updates"
```

---

### Task 8: Run precommit checks and verify everything works

**Files:** None (verification only)

**Step 1: Run the precommit alias**

Run: `mix precommit`
Expected: Compilation with zero warnings, formatting clean, all tests pass.

**Step 2: If formatting issues, fix them**

Run: `mix format`
Then re-run: `mix precommit`

**Step 3: Manually verify dev server produces JSON logs**

Run: `mix phx.server` (requires GITHUB_TOKEN and at least one bookmarked repo or org)
Expected: JSON-formatted log output in the terminal. Each line should be valid JSON with `time`, `severity`, `message`, and `metadata` fields.

**Step 4: Commit any formatting fixes**

```bash
git add -A
git commit -m "chore: fix formatting from precommit"
```

(Skip this commit if no changes were needed.)
