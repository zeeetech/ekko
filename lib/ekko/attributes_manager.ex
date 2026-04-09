defmodule Ekko.AttributesManager do
  @moduledoc """
  Holds the three attribute scopes Alexa skills work with:

    * `:request_attributes` — in-memory only, dropped when the request
      finishes. Useful for handing data from interceptors to handlers.
    * `:session_attributes` — read from `request.session.attributes` on
      construction; merged back into the response by the dispatcher.
    * `:persistent_attributes` — backed by a persistence adapter (e.g.
      DynamoDB, ETS, Postgres). Left as `nil` in Milestone 2; the adapter
      behaviour and getters/setters land in a later milestone.
  """

  alias Ekko.Request
  alias Ekko.Request.Session

  @type t :: %__MODULE__{
          request_attributes: map(),
          session_attributes: map(),
          persistent_attributes: nil
        }

  defstruct request_attributes: %{}, session_attributes: %{}, persistent_attributes: nil

  @doc """
  Builds a fresh manager from a parsed `Ekko.Request`. Pulls
  `session.attributes` when present; falls back to `%{}` for sessionless
  (AudioPlayer) requests.
  """
  @spec new(Request.t()) :: t()
  def new(%Request{session: %Session{attributes: attrs}}) when is_map(attrs) do
    %__MODULE__{session_attributes: attrs}
  end

  def new(%Request{}), do: %__MODULE__{}

  @spec get_request_attributes(t()) :: map()
  def get_request_attributes(%__MODULE__{request_attributes: attrs}), do: attrs

  @spec set_request_attributes(t(), map()) :: t()
  def set_request_attributes(%__MODULE__{} = mgr, attrs) when is_map(attrs) do
    %{mgr | request_attributes: attrs}
  end

  @spec get_session_attributes(t()) :: map()
  def get_session_attributes(%__MODULE__{session_attributes: attrs}), do: attrs

  @spec set_session_attributes(t(), map()) :: t()
  def set_session_attributes(%__MODULE__{} = mgr, attrs) when is_map(attrs) do
    %{mgr | session_attributes: attrs}
  end
end
