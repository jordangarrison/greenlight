defmodule Greenlight.Pollers do
  @moduledoc """
  Public API for subscribing to pipeline pollers.
  """

  alias Greenlight.GitHub.Poller

  def subscribe(owner, repo, ref) do
    # Subscribe to PubSub topic
    topic = "pipeline:#{owner}/#{repo}:#{ref}"
    Phoenix.PubSub.subscribe(Greenlight.PubSub, topic)

    # Find or start the poller
    case Registry.lookup(Greenlight.PollerRegistry, {owner, repo, ref}) do
      [{pid, _}] ->
        Poller.subscribe(pid)

      [] ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Greenlight.PollerSupervisor,
            {Poller, owner: owner, repo: repo, ref: ref}
          )

        Poller.subscribe(pid)
    end
  end
end
