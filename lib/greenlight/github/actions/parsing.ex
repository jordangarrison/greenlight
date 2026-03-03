defmodule Greenlight.GitHub.Actions.Parsing do
  @moduledoc false

  def parse_status(nil), do: nil
  def parse_status("queued"), do: :queued
  def parse_status("in_progress"), do: :in_progress
  def parse_status("completed"), do: :completed
  def parse_status(other) when is_binary(other), do: String.to_existing_atom(other)
  def parse_status(other) when is_atom(other), do: other

  def parse_conclusion(nil), do: nil
  def parse_conclusion("success"), do: :success
  def parse_conclusion("failure"), do: :failure
  def parse_conclusion("cancelled"), do: :cancelled
  def parse_conclusion("skipped"), do: :skipped
  def parse_conclusion(other) when is_binary(other), do: String.to_existing_atom(other)
  def parse_conclusion(other) when is_atom(other), do: other

  def parse_datetime(nil), do: nil
  def parse_datetime(%DateTime{} = dt), do: dt

  def parse_datetime(str) when is_binary(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end
end
