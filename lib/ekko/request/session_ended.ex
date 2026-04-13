defmodule Ekko.Request.SessionEnded do
  @moduledoc """
  A `SessionEndedRequest` is dispatched when the user ends the session, the
  session times out, or an error causes Alexa to terminate the session. The
  skill cannot return a non-empty response to this request.
  """

  @type reason :: :user_initiated | :error | :exceeded_max_reprompts | nil

  @type t :: %__MODULE__{
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil,
          reason: reason(),
          error: map() | nil
        }

  defstruct [:request_id, :timestamp, :locale, :reason, :error]

  @doc "Parses a decoded `SessionEndedRequest` JSON map."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"type" => "SessionEndedRequest", "requestId" => request_id, "timestamp" => ts} = raw) do
    case DateTime.from_iso8601(ts) do
      {:ok, datetime, _offset} ->
        {:ok,
         %__MODULE__{
           request_id: request_id,
           timestamp: datetime,
           locale: Map.get(raw, "locale"),
           reason: parse_reason(Map.get(raw, "reason")),
           error: Map.get(raw, "error")
         }}

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  def from_map(_), do: {:error, :invalid_session_ended_request}

  defp parse_reason(nil), do: nil
  defp parse_reason("USER_INITIATED"), do: :user_initiated
  defp parse_reason("ERROR"), do: :error
  defp parse_reason("EXCEEDED_MAX_REPROMPTS"), do: :exceeded_max_reprompts
  defp parse_reason(_), do: nil
end
