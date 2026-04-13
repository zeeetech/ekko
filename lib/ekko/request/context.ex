defmodule Ekko.Request.Context do
  @moduledoc """
  The `Context` object that accompanies every Alexa request, containing the
  `System` object and — when the device has audio state — an AudioPlayer state
  snapshot (returned as a plain map; see `Ekko.Request.AudioPlayer`).
  """

  alias Ekko.Request.AudioPlayer
  alias Ekko.Request.System

  @type t :: %__MODULE__{
          system: System.t() | nil,
          audio_player: AudioPlayer.playback_state() | nil
        }

  defstruct [:system, :audio_player]

  @doc "Parses a decoded context JSON map."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(raw) when is_map(raw) do
    with {:ok, system} <- parse_system(Map.get(raw, "System")),
         {:ok, audio_player} <- parse_audio_player(Map.get(raw, "AudioPlayer")) do
      {:ok, %__MODULE__{system: system, audio_player: audio_player}}
    end
  end

  def from_map(_), do: {:error, :invalid_context}

  defp parse_system(nil), do: {:ok, nil}
  defp parse_system(raw), do: System.from_map(raw)

  defp parse_audio_player(nil), do: {:ok, nil}
  defp parse_audio_player(raw), do: AudioPlayer.state_from_map(raw)
end
