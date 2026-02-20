defmodule Greenlight.RequestLogger do
  @moduledoc """
  Telemetry handler that emits a wide event for each HTTP request.

  Attaches to `[:phoenix, :endpoint, :stop]` and logs method, path,
  status, duration, and remote IP as a single structured event.
  """

  alias Greenlight.WideEvent

  def attach do
    :telemetry.attach(
      "greenlight-request-logger",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  def handle_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    conn = metadata.conn
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    WideEvent.emit(
      "http.request",
      [
        http_method: conn.method,
        http_path: conn.request_path,
        http_status: conn.status,
        http_duration_ms: duration_ms,
        http_remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
      ],
      level: :info
    )
  end
end
