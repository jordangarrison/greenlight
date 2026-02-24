defmodule Greenlight.TimeHelpersTest do
  use ExUnit.Case, async: true

  alias Greenlight.TimeHelpers

  test "relative_time/1 returns 'just now' for recent timestamps" do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(now) == "just now"
  end

  test "relative_time/1 returns minutes ago" do
    past = DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "5m ago"
  end

  test "relative_time/1 returns hours ago" do
    past = DateTime.utc_now() |> DateTime.add(-7200, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "2h ago"
  end

  test "relative_time/1 returns days ago" do
    past = DateTime.utc_now() |> DateTime.add(-172_800, :second) |> DateTime.to_iso8601()
    assert TimeHelpers.relative_time(past) == "2d ago"
  end

  test "relative_time/1 returns empty string for nil input" do
    assert TimeHelpers.relative_time(nil) == ""
  end
end
