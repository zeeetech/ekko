defmodule Ekko.Request.Session do
  @moduledoc """
  The Alexa session object that accompanies session-bearing requests
  (`LaunchRequest`, `IntentRequest`, `SessionEndedRequest`).

  AudioPlayer requests carry no session — they will leave the parent envelope's
  `:session` field set to `nil`.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          new?: boolean(),
          attributes: map(),
          application: map(),
          user: map()
        }

  defstruct [:session_id, :new?, :application, :user, attributes: %{}]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"sessionId" => session_id, "new" => new?, "application" => application, "user" => user} = raw) do
    {:ok,
     %__MODULE__{
       session_id: session_id,
       new?: new?,
       attributes: Map.get(raw, "attributes", %{}),
       application: application,
       user: user
     }}
  end

  def from_map(_), do: {:error, :invalid_session}
end
