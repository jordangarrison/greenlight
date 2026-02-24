defmodule Greenlight.GitHub.UserInsightsServer do
  @moduledoc """
  GenServer that periodically fetches authenticated user profile and
  recent activity (PRs, commits) from the GitHub API and caches the
  results. Dashboard reads from the cache on mount for instant render
  and subscribes via PubSub for live updates.
  """

  use GenServer
  require Logger

  alias Greenlight.GitHub.Client
  alias Greenlight.{Cache, WideEvent}

  @poll_interval :timer.minutes(5)
  @pubsub_topic "user_insights"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_cached do
    case Cache.get(:user_insights) do
      {:ok, data} -> data
      :miss -> %{user: nil, prs: [], commits: [], loading: true}
    end
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Greenlight.PubSub, @pubsub_topic)
  end

  @impl true
  def init(_opts) do
    send(self(), :poll)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    try do
      WideEvent.with_context("user_insights.poll", [level: :debug], fn ->
        data = fetch_user_insights()
        Cache.put(:user_insights, data)

        Phoenix.PubSub.broadcast(
          Greenlight.PubSub,
          @pubsub_topic,
          {:user_insights_update, data}
        )

        WideEvent.add(
          prs_count: length(data.prs),
          commits_count: length(data.commits),
          has_user: data.user != nil
        )
      end)
    rescue
      e ->
        Logger.error("User insights poll failed: #{Exception.message(e)}")
    end

    schedule_poll()
    {:noreply, state}
  end

  defp fetch_user_insights do
    case Client.get_authenticated_user() do
      {:ok, user} ->
        prs_task = Task.async(fn -> Client.search_user_prs(user.login) end)
        commits_task = Task.async(fn -> Client.search_user_commits(user.login) end)

        prs =
          case Task.await(prs_task) do
            {:ok, prs} -> prs
            {:error, _} -> []
          end

        commits =
          case Task.await(commits_task) do
            {:ok, commits} -> commits
            {:error, _} -> []
          end

        %{user: user, prs: prs, commits: commits, loading: false}

      {:error, _} ->
        %{user: nil, prs: [], commits: [], loading: false}
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
