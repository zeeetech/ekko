defmodule Ekko.Request.Slot do
  @moduledoc """
  A single slot value within an intent. Slots may be confirmed by the user, may
  carry entity-resolution results, and may be empty (the user did not provide a
  value).

  In Milestone 1 the `resolutions` field is kept as a raw decoded JSON map.
  Full entity-resolution modeling will land when a handler needs to read into
  it.
  """

  @type confirmation_status :: :none | :confirmed | :denied

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t() | nil,
          confirmation_status: confirmation_status(),
          resolutions: map() | nil
        }

  defstruct [:name, :value, :resolutions, confirmation_status: :none]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"name" => name} = raw) do
    {:ok,
     %__MODULE__{
       name: name,
       value: Map.get(raw, "value"),
       confirmation_status: parse_status(Map.get(raw, "confirmationStatus")),
       resolutions: Map.get(raw, "resolutions")
     }}
  end

  def from_map(_), do: {:error, :invalid_slot}

  defp parse_status("CONFIRMED"), do: :confirmed
  defp parse_status("DENIED"), do: :denied
  defp parse_status(_), do: :none
end
