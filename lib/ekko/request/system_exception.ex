defmodule Ekko.Request.SystemException do
  @moduledoc """
  Sent by Alexa when a previous skill response caused a downstream error
  (e.g. an `AudioPlayer.Play` directive pointed at an unreachable URL).

  The `:error` field always carries a `type` and `message`. The `:cause`
  field, when present, contains the `requestId` of the response that
  triggered the exception.

  This is a terminal request — the skill should log the error but cannot
  send a meaningful response back.
  """

  @type t :: %__MODULE__{
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil,
          error: %{type: String.t(), message: String.t()},
          cause: %{request_id: String.t() | nil} | nil
        }

  defstruct [:request_id, :timestamp, :locale, :error, :cause]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(
        %{
          "type" => "System.ExceptionEncountered",
          "requestId" => request_id,
          "timestamp" => ts,
          "error" => %{"type" => error_type, "message" => error_message}
        } = raw
      ) do
    case DateTime.from_iso8601(ts) do
      {:ok, datetime, _offset} ->
        {:ok,
         %__MODULE__{
           request_id: request_id,
           timestamp: datetime,
           locale: Map.get(raw, "locale"),
           error: %{type: error_type, message: error_message},
           cause: parse_cause(Map.get(raw, "cause"))
         }}

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  def from_map(_), do: {:error, :invalid_system_exception_request}

  defp parse_cause(nil), do: nil

  defp parse_cause(%{} = cause) do
    %{request_id: Map.get(cause, "requestId")}
  end
end
