defmodule Ekko.Request.PlaybackController do
  @moduledoc """
  PlaybackController requests are fired when the user issues a transport
  command via voice ("Alexa, next") or hardware buttons. Unlike
  `Ekko.Request.AudioPlayer` events (which are notifications about a stream
  the skill already started), PlaybackController commands are the user
  asking the skill to *do* something — the skill is expected to respond
  with the appropriate `AudioPlayer.*` directive.

  All five command variants collapse into one struct distinguished by
  the `:command` field.
  """

  @type command :: :play | :pause | :next | :previous | :resume

  @type t :: %__MODULE__{
          command: command(),
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil
        }

  defstruct [:command, :request_id, :timestamp, :locale]

  @doc "Parses a decoded `PlaybackController.*` JSON map into a struct distinguished by `:command`."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"type" => "PlaybackController." <> sub, "requestId" => request_id, "timestamp" => ts} = raw) do
    with {:ok, command} <- parse_command(sub),
         {:ok, datetime, _offset} <- DateTime.from_iso8601(ts) do
      {:ok,
       %__MODULE__{
         command: command,
         request_id: request_id,
         timestamp: datetime,
         locale: Map.get(raw, "locale")
       }}
    else
      {:error, _} = err -> err
    end
  end

  def from_map(_), do: {:error, :invalid_playback_controller_request}

  defp parse_command("PlayCommandIssued"), do: {:ok, :play}
  defp parse_command("PauseCommandIssued"), do: {:ok, :pause}
  defp parse_command("NextCommandIssued"), do: {:ok, :next}
  defp parse_command("PreviousCommandIssued"), do: {:ok, :previous}
  defp parse_command("ResumeCommandIssued"), do: {:ok, :resume}
  defp parse_command(other), do: {:error, {:unknown_playback_controller_command, other}}
end
