defmodule Ekko.Request.System do
  @moduledoc """
  The `System` object nested inside `Context`. Carries the application id, user
  identity, device identity, and the API endpoint/access token Alexa expects
  the skill to use when calling back into the Alexa service.

  In Milestone 1 the `application`, `user`, and `device` fields are kept as raw
  decoded JSON maps — they will be promoted to typed structs in a later
  milestone, once a handler actually needs to read into them.
  """

  @type t :: %__MODULE__{
          application: map() | nil,
          user: map() | nil,
          device: map() | nil,
          api_endpoint: String.t() | nil,
          api_access_token: String.t() | nil
        }

  defstruct [:application, :user, :device, :api_endpoint, :api_access_token]

  @doc "Parses a decoded `context.System` JSON map."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(raw) when is_map(raw) do
    {:ok,
     %__MODULE__{
       application: Map.get(raw, "application"),
       user: Map.get(raw, "user"),
       device: Map.get(raw, "device"),
       api_endpoint: Map.get(raw, "apiEndpoint"),
       api_access_token: Map.get(raw, "apiAccessToken")
     }}
  end

  def from_map(_), do: {:error, :invalid_system}
end
