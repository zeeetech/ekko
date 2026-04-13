defmodule Ekko.Request.Launch do
  @moduledoc """
  A `LaunchRequest` is sent when the user invokes the skill without a specific
  intent ("Alexa, open my skill").
  """

  @type t :: %__MODULE__{
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil
        }

  defstruct [:request_id, :timestamp, :locale]

  @doc "Parses a decoded `LaunchRequest` JSON map."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"type" => "LaunchRequest", "requestId" => request_id, "timestamp" => ts} = raw) do
    case DateTime.from_iso8601(ts) do
      {:ok, datetime, _offset} ->
        {:ok,
         %__MODULE__{
           request_id: request_id,
           timestamp: datetime,
           locale: Map.get(raw, "locale")
         }}

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  def from_map(_), do: {:error, :invalid_launch_request}
end
