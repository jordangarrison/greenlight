defmodule Greenlight.GitHub.Poller do
  @moduledoc """
  GenServer that polls GitHub Actions API for workflow runs
  and broadcasts updates via PubSub.
  """

  use GenServer
  require Logger

  alias Greenlight.GitHub.{Client, WorkflowGraph}
  alias Greenlight.WideEvent

  @active_interval 10_000
  @idle_interval 60_000

  defstruct [
    :owner,
    :repo,
    :ref,
    :poll_interval,
    :last_state,
    monitors: %{},
    subscriber_count: 0,
    workflow_defs: %{}
  ]

  def start_link(opts) do
    owner = Keyword.fetch!(opts, :owner)
    repo = Keyword.fetch!(opts, :repo)
    ref = Keyword.fetch!(opts, :ref)
    name = {:via, Registry, {Greenlight.PollerRegistry, {owner, repo, ref}}}

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def subscribe(pid) do
    GenServer.call(pid, {:subscribe, self()})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      owner: Keyword.fetch!(opts, :owner),
      repo: Keyword.fetch!(opts, :repo),
      ref: Keyword.fetch!(opts, :ref),
      poll_interval: Keyword.get(opts, :poll_interval, @active_interval)
    }

    Logger.metadata(
      poller_owner: state.owner,
      poller_repo: state.repo,
      poller_ref: state.ref
    )

    unless Keyword.get(opts, :skip_initial_poll, false) do
      send(self(), :poll)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    mon_ref = Process.monitor(pid)

    state = %{
      state
      | monitors: Map.put(state.monitors, mon_ref, pid),
        subscriber_count: state.subscriber_count + 1
    }

    reply = state.last_state
    {:reply, {:ok, reply}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = do_poll(state)
    schedule_poll(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, mon_ref, :process, _pid, _reason}, state) do
    state = %{
      state
      | monitors: Map.delete(state.monitors, mon_ref),
        subscriber_count: state.subscriber_count - 1
    }

    if state.subscriber_count <= 0 do
      Process.send_after(self(), :check_shutdown, 60_000)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_shutdown, state) do
    if state.subscriber_count <= 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

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

  defp fetch_jobs_for_runs(owner, repo, runs) do
    Enum.map(runs, fn run ->
      case Client.list_jobs(owner, repo, run.id) do
        {:ok, jobs} -> %{run | jobs: jobs}
        {:error, _} -> run
      end
    end)
  end

  defp resolve_all_job_needs(owner, repo, runs, workflow_defs) do
    # Collect unique workflow paths to fetch
    paths_to_fetch =
      runs
      |> Enum.filter(& &1.path)
      |> Enum.uniq_by(& &1.path)

    # Fetch or use cached workflow YAML content
    workflow_defs =
      Enum.reduce(paths_to_fetch, workflow_defs, fn run, defs ->
        cache_key = {run.path, run.head_sha}

        if Map.has_key?(defs, cache_key) do
          defs
        else
          case Client.get_repo_content(owner, repo, run.path, run.head_sha) do
            {:ok, content} -> Map.put(defs, cache_key, content)
            {:error, _} -> defs
          end
        end
      end)

    # Apply resolved needs to each run's jobs
    runs =
      Enum.map(runs, fn run ->
        cache_key = {run.path, run.head_sha}

        case Map.get(workflow_defs, cache_key) do
          nil ->
            run

          yaml_content ->
            resolved_jobs = WorkflowGraph.resolve_job_needs(yaml_content, run.jobs)
            %{run | jobs: resolved_jobs}
        end
      end)

    {runs, workflow_defs}
  end

  defp compute_interval(runs) do
    any_active? = Enum.any?(runs, &(&1.status == :in_progress))
    if any_active?, do: @active_interval, else: @idle_interval
  end

  defp schedule_poll(state) do
    Process.send_after(self(), :poll, state.poll_interval)
  end
end
