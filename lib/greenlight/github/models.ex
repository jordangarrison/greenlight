defmodule Greenlight.GitHub.Models do
  @moduledoc """
  Data structures for GitHub Actions API responses.
  """

  defmodule Step do
    @moduledoc false
    defstruct [:name, :status, :conclusion, :number, :started_at, :completed_at]

    def from_api(data) do
      %__MODULE__{
        name: data["name"],
        status: parse_status(data["status"]),
        conclusion: parse_conclusion(data["conclusion"]),
        number: data["number"],
        started_at: parse_datetime(data["started_at"]),
        completed_at: parse_datetime(data["completed_at"])
      }
    end

    defp parse_status(nil), do: nil
    defp parse_status("queued"), do: :queued
    defp parse_status("in_progress"), do: :in_progress
    defp parse_status("completed"), do: :completed
    defp parse_status(other), do: String.to_atom(other)

    defp parse_conclusion(nil), do: nil
    defp parse_conclusion("success"), do: :success
    defp parse_conclusion("failure"), do: :failure
    defp parse_conclusion("cancelled"), do: :cancelled
    defp parse_conclusion("skipped"), do: :skipped
    defp parse_conclusion(other), do: String.to_atom(other)

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end

  defmodule Job do
    @moduledoc false
    defstruct [:id, :name, :status, :conclusion, :started_at, :completed_at,
               :current_step, :html_url, steps: [], needs: []]

    def from_api(data) do
      steps = Enum.map(data["steps"] || [], &Step.from_api/1)

      current_step =
        steps
        |> Enum.find(&(&1.status == :in_progress))
        |> case do
          nil -> nil
          step -> step.name
        end

      %__MODULE__{
        id: data["id"],
        name: data["name"],
        status: Step.from_api(%{"status" => data["status"]}).status,
        conclusion: Step.from_api(%{"conclusion" => data["conclusion"]}).conclusion,
        started_at: parse_datetime(data["started_at"]),
        completed_at: parse_datetime(data["completed_at"]),
        html_url: data["html_url"],
        current_step: current_step,
        steps: steps
      }
    end

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end

  defmodule WorkflowRun do
    @moduledoc false
    defstruct [:id, :name, :workflow_id, :status, :conclusion, :head_sha,
               :event, :html_url, :created_at, :updated_at, jobs: []]

    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        workflow_id: data["workflow_id"],
        status: Step.from_api(%{"status" => data["status"]}).status,
        conclusion: Step.from_api(%{"conclusion" => data["conclusion"]}).conclusion,
        head_sha: data["head_sha"],
        event: data["event"],
        html_url: data["html_url"],
        created_at: parse_datetime(data["created_at"]),
        updated_at: parse_datetime(data["updated_at"])
      }
    end

    defp parse_datetime(nil), do: nil

    defp parse_datetime(str) do
      {:ok, dt, _} = DateTime.from_iso8601(str)
      dt
    end
  end
end
