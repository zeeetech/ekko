defmodule Ekko.Request do
  @moduledoc """
  Top-level Alexa request envelope and parser entry point.

  An `Ekko.Request.t()` wraps the protocol version, the optional session, the
  context, and the typed inner request struct (one of `Ekko.Request.Launch`,
  `Ekko.Request.Intent`, `Ekko.Request.SessionEnded`, or
  `Ekko.Request.AudioPlayer`).

  The `:session` field is `nil` for AudioPlayer playback requests, which
  Amazon delivers without a session object.
  """

  alias Ekko.Request.AudioPlayer
  alias Ekko.Request.Context
  alias Ekko.Request.Intent
  alias Ekko.Request.Launch
  alias Ekko.Request.Session
  alias Ekko.Request.SessionEnded

  @type inner ::
          Launch.t()
          | Intent.t()
          | SessionEnded.t()
          | AudioPlayer.t()

  @type t :: %__MODULE__{
          version: String.t(),
          session: Session.t() | nil,
          context: Context.t(),
          request: inner()
        }

  defstruct [:version, :session, :context, :request]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"version" => version, "context" => context_raw, "request" => request_raw} = raw) do
    with {:ok, context} <- Context.from_map(context_raw),
         {:ok, inner} <- parse_request(request_raw),
         {:ok, session} <- parse_session(Map.get(raw, "session")) do
      {:ok,
       %__MODULE__{
         version: version,
         session: session,
         context: context,
         request: inner
       }}
    end
  end

  def from_map(_), do: {:error, :invalid_request}

  defp parse_session(nil), do: {:ok, nil}
  defp parse_session(raw), do: Session.from_map(raw)

  defp parse_request(%{"type" => "LaunchRequest"} = raw), do: Launch.from_map(raw)
  defp parse_request(%{"type" => "IntentRequest"} = raw), do: Intent.from_map(raw)
  defp parse_request(%{"type" => "SessionEndedRequest"} = raw), do: SessionEnded.from_map(raw)
  defp parse_request(%{"type" => "AudioPlayer." <> _} = raw), do: AudioPlayer.from_map(raw)
  defp parse_request(%{"type" => type}), do: {:error, {:unknown_request_type, type}}
  defp parse_request(_), do: {:error, :malformed_request}
end
