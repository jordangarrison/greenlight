defmodule Greenlight.GitHub.Poller do
  @moduledoc """
  GenServer that polls GitHub Actions API for workflow runs
  and broadcasts updates via PubSub.
  """

  use GenServer

  alias Greenlight.GitHub.{Client, WorkflowGraph}

  @active_interval 10_000
  @idle_interval 60_000

  defstruct [:owner, :repo, :ref, :poll_interval, :last_state, monitors: %{}, subscriber_count: 0]

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

    unless Keyword.get(opts, :skip_initial_poll, false) do
      send(self(), :poll)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    mon_ref = Process.monitor(pid)

    state = %{state |
      monitors: Map.put(state.monitors, mon_ref, pid),
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
    state = %{state |
      monitors: Map.delete(state.monitors, mon_ref),
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
    topic = "pipeline:#{state.owner}/#{state.repo}:#{state.ref}"

    with {:ok, runs} <- Client.list_workflow_runs(state.owner, state.repo, head_sha: state.ref),
         runs_with_jobs <- fetch_jobs_for_runs(state.owner, state.repo, runs) do
      graph_data = WorkflowGraph.build_workflow_dag(runs_with_jobs)

      if graph_data != state.last_state do
        Phoenix.PubSub.broadcast(
          Greenlight.PubSub,
          topic,
          {:pipeline_update, graph_data}
        )
      end

      %{state | last_state: graph_data, poll_interval: compute_interval(runs_with_jobs)}
    else
      {:error, _reason} ->
        state
    end
  end

  defp fetch_jobs_for_runs(owner, repo, runs) do
    Enum.map(runs, fn run ->
      case Client.list_jobs(owner, repo, run.id) do
        {:ok, jobs} -> %{run | jobs: jobs}
        {:error, _} -> run
      end
    end)
  end

  defp compute_interval(runs) do
    any_active? = Enum.any?(runs, &(&1.status == :in_progress))
    if any_active?, do: @active_interval, else: @idle_interval
  end

  defp schedule_poll(state) do
    Process.send_after(self(), :poll, state.poll_interval)
  end
end
