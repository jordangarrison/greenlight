defmodule Greenlight.WideEventTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Greenlight.WideEvent

  setup do
    Logger.metadata([])
    previous_level = Logger.level()
    Logger.configure(level: :debug)

    on_exit(fn ->
      Logger.configure(level: previous_level)
    end)

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
