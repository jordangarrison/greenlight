defmodule Greenlight.TimeHelpers do
  @moduledoc """
  Helpers for formatting timestamps as relative time strings.
  """

  def relative_time(nil), do: ""

  def relative_time(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} ->
        diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
        format_diff(diff)

      _ ->
        ""
    end
  end

  defp format_diff(seconds) when seconds < 60, do: "just now"
  defp format_diff(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m ago"
  defp format_diff(seconds) when seconds < 86400, do: "#{div(seconds, 3600)}h ago"
  defp format_diff(seconds), do: "#{div(seconds, 86400)}d ago"
end
