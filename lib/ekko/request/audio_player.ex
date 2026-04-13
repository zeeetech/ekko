defmodule Ekko.Request.AudioPlayer do
  @moduledoc """
  All five AudioPlayer playback events collapse into a single struct
  distinguished by the `:event` field. AudioPlayer requests carry no session;
  the parent envelope's `:session` will be `nil`.

  This module also exposes `state_from_map/1`, used by `Ekko.Request.Context`
  to parse the AudioPlayer state snapshot that may accompany any request when
  the device has an active stream. The snapshot uses a separate map shape
  (it has `playerActivity` and no `requestId`/`timestamp`), so it returns a
  plain map rather than a struct — there's only one consumer.

  ## Event variants

    * `:started` — playback began
    * `:finished` — stream completed naturally
    * `:stopped` — user or directive stopped playback
    * `:nearly_finished` — time to enqueue the next track
    * `:failed` — playback errored; `:error` and `:current_playback_state`
      are populated
  """

  @type event :: :started | :finished | :stopped | :nearly_finished | :failed

  @type playback_state :: %{
          token: String.t() | nil,
          offset_in_milliseconds: non_neg_integer() | nil,
          player_activity: atom() | nil
        }

  @type t :: %__MODULE__{
          event: event(),
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil,
          token: String.t(),
          offset_in_milliseconds: non_neg_integer(),
          error: %{type: String.t(), message: String.t()} | nil,
          current_playback_state: playback_state() | nil
        }

  defstruct [
    :event,
    :request_id,
    :timestamp,
    :locale,
    :token,
    :offset_in_milliseconds,
    :error,
    :current_playback_state
  ]

  @doc "Parses a decoded `AudioPlayer.*` JSON map into a struct distinguished by `:event`."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(
        %{
          "type" => "AudioPlayer." <> sub,
          "requestId" => request_id,
          "timestamp" => ts,
          "token" => token,
          "offsetInMilliseconds" => offset
        } = raw
      ) do
    with {:ok, event} <- parse_event(sub),
         {:ok, datetime, _offset} <- DateTime.from_iso8601(ts) do
      {:ok,
       %__MODULE__{
         event: event,
         request_id: request_id,
         timestamp: datetime,
         locale: Map.get(raw, "locale"),
         token: token,
         offset_in_milliseconds: offset,
         error: parse_error(Map.get(raw, "error")),
         current_playback_state: parse_state(Map.get(raw, "currentPlaybackState"))
       }}
    else
      {:error, _} = err -> err
    end
  end

  def from_map(_), do: {:error, :invalid_audio_player_request}

  @doc """
  Parses an AudioPlayer state snapshot map (from `context.AudioPlayer`).
  Returns a plain map rather than a struct; the snapshot has only three
  fields and a single consumer.
  """
  @spec state_from_map(map()) :: {:ok, playback_state()} | {:error, term()}
  def state_from_map(raw) when is_map(raw) do
    {:ok,
     %{
       token: Map.get(raw, "token"),
       offset_in_milliseconds: Map.get(raw, "offsetInMilliseconds"),
       player_activity: parse_activity(Map.get(raw, "playerActivity"))
     }}
  end

  def state_from_map(_), do: {:error, :invalid_audio_player_state}

  defp parse_event("PlaybackStarted"), do: {:ok, :started}
  defp parse_event("PlaybackFinished"), do: {:ok, :finished}
  defp parse_event("PlaybackStopped"), do: {:ok, :stopped}
  defp parse_event("PlaybackNearlyFinished"), do: {:ok, :nearly_finished}
  defp parse_event("PlaybackFailed"), do: {:ok, :failed}
  defp parse_event(other), do: {:error, {:unknown_audio_player_event, other}}

  defp parse_error(nil), do: nil

  defp parse_error(%{"type" => type, "message" => message}), do: %{type: type, message: message}

  defp parse_error(_), do: nil

  defp parse_state(nil), do: nil

  defp parse_state(raw) when is_map(raw) do
    %{
      token: Map.get(raw, "token"),
      offset_in_milliseconds: Map.get(raw, "offsetInMilliseconds"),
      player_activity: parse_activity(Map.get(raw, "playerActivity"))
    }
  end

  defp parse_activity(nil), do: nil
  defp parse_activity("IDLE"), do: :idle
  defp parse_activity("PAUSED"), do: :paused
  defp parse_activity("PLAYING"), do: :playing
  defp parse_activity("BUFFER_UNDERRUN"), do: :buffer_underrun
  defp parse_activity("FINISHED"), do: :finished
  defp parse_activity("STOPPED"), do: :stopped
  defp parse_activity(_), do: nil
end
