defmodule Greenlight.GitHub.ReqLogger do
  @moduledoc """
  Req plugin that emits a wide event for every GitHub API call.

  Captures request/response metadata including endpoint, status, duration,
  response size, and GitHub rate limit headers.

  ## Usage

      Req.new()
      |> ReqLogger.attach()
      |> Req.get!(url: "/repos/owner/repo")

  ## Log Levels

    * `:debug` -- successful 2xx responses
    * `:info` -- rate limit warnings (remaining < 100)
    * `:error` -- 4xx/5xx responses and connection errors
  """

  alias Greenlight.WideEvent

  def attach(%Req.Request{} = request) do
    request
    |> Req.Request.append_request_steps(wide_event_start: &start_step/1)
    |> Req.Request.append_response_steps(wide_event_stop: &stop_step/1)
    |> Req.Request.append_error_steps(wide_event_error: &error_step/1)
  end

  defp start_step(request) do
    Req.Request.put_private(request, :wide_event_start, System.monotonic_time(:millisecond))
  end

  defp stop_step({request, response}) do
    start =
      Req.Request.get_private(request, :wide_event_start, System.monotonic_time(:millisecond))

    duration_ms = System.monotonic_time(:millisecond) - start

    rate_remaining = get_int_header(response, "x-ratelimit-remaining")
    rate_reset = get_int_header(response, "x-ratelimit-reset")

    level =
      cond do
        response.status >= 400 -> :error
        rate_remaining != nil and rate_remaining < 100 -> :info
        true -> :debug
      end

    body_size =
      case response.body do
        body when is_binary(body) -> byte_size(body)
        body when is_map(body) or is_list(body) -> body |> Jason.encode!() |> byte_size()
        _ -> 0
      end

    WideEvent.emit(
      "github.api_call",
      [
        github_endpoint: URI.to_string(request.url),
        github_method: to_string(request.method),
        github_status: response.status,
        github_duration_ms: duration_ms,
        github_response_size: body_size,
        github_rate_limit_remaining: rate_remaining,
        github_rate_limit_reset: rate_reset
      ],
      level: level
    )

    {request, response}
  end

  defp error_step({request, exception}) do
    start =
      Req.Request.get_private(request, :wide_event_start, System.monotonic_time(:millisecond))

    duration_ms = System.monotonic_time(:millisecond) - start

    WideEvent.emit(
      "github.api_call",
      [
        github_endpoint: URI.to_string(request.url),
        github_method: to_string(request.method),
        github_status: :error,
        github_duration_ms: duration_ms,
        github_error: Exception.message(exception),
        github_error_type: inspect(exception.__struct__)
      ],
      level: :error
    )

    {request, exception}
  end

  defp get_int_header(response, header_name) do
    case Req.Response.get_header(response, header_name) do
      [value | _] -> parse_int(value)
      _ -> nil
    end
  end

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(_), do: nil
end
