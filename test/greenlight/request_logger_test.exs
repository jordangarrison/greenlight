defmodule Greenlight.RequestLoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Greenlight.RequestLogger

  setup do
    prev_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: prev_level) end)
    :ok
  end

  describe "handle_event/4" do
    test "emits an http.request wide event" do
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
