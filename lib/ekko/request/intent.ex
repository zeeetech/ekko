defmodule Ekko.Request.Intent do
  @moduledoc """
  An `IntentRequest` is dispatched when Alexa matches the user's utterance
  against one of the skill's intents.

  The nested intent payload (`intent.name`, `intent.confirmationStatus`,
  `intent.slots`) is decoded inline as a plain map with atom keys, since the
  shape is small and there is no behavior attached. Pattern matching from a
  handler reads naturally:

      def can_handle?(%{request_envelope: %{request: %Ekko.Request.Intent{
            intent: %{name: "PlayMusicIntent"}
          }}}), do: true
  """

  alias Ekko.Request.Slot

  @type dialog_state :: :started | :in_progress | :completed | nil

  @type confirmation_status :: :none | :confirmed | :denied

  @type intent_data :: %{
          name: String.t(),
          confirmation_status: confirmation_status(),
          slots: %{optional(String.t()) => Slot.t()}
        }

  @type t :: %__MODULE__{
          request_id: String.t(),
          timestamp: DateTime.t(),
          locale: String.t() | nil,
          dialog_state: dialog_state(),
          intent: intent_data()
        }

  defstruct [:request_id, :timestamp, :locale, :dialog_state, :intent]

  @doc "Parses a decoded `IntentRequest` JSON map."
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"type" => "IntentRequest", "requestId" => request_id, "timestamp" => ts, "intent" => intent_raw} = raw) do
    with {:ok, datetime, _offset} <- DateTime.from_iso8601(ts),
         {:ok, intent} <- parse_intent(intent_raw) do
      {:ok,
       %__MODULE__{
         request_id: request_id,
         timestamp: datetime,
         locale: Map.get(raw, "locale"),
         dialog_state: parse_dialog_state(Map.get(raw, "dialogState")),
         intent: intent
       }}
    else
      {:error, _} = err -> err
      _ -> {:error, :invalid_timestamp}
    end
  end

  def from_map(_), do: {:error, :invalid_intent_request}

  defp parse_intent(%{"name" => name} = raw) do
    with {:ok, slots} <- parse_slots(Map.get(raw, "slots")) do
      {:ok,
       %{
         name: name,
         confirmation_status: parse_status(Map.get(raw, "confirmationStatus")),
         slots: slots
       }}
    end
  end

  defp parse_intent(_), do: {:error, :invalid_intent}

  defp parse_slots(nil), do: {:ok, %{}}

  defp parse_slots(raw) when is_map(raw) do
    Enum.reduce_while(raw, {:ok, %{}}, fn {name, slot_raw}, {:ok, acc} ->
      case Slot.from_map(slot_raw) do
        {:ok, slot} -> {:cont, {:ok, Map.put(acc, name, slot)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_slots(_), do: {:error, :invalid_slots}

  defp parse_status("CONFIRMED"), do: :confirmed
  defp parse_status("DENIED"), do: :denied
  defp parse_status(_), do: :none

  defp parse_dialog_state(nil), do: nil
  defp parse_dialog_state("STARTED"), do: :started
  defp parse_dialog_state("IN_PROGRESS"), do: :in_progress
  defp parse_dialog_state("COMPLETED"), do: :completed
  defp parse_dialog_state(_), do: nil
end
