defmodule Ekko.RequestPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ekko.Request

  @locales ["en-US", "en-GB", "de-DE", "ja-JP", "pt-BR", "fr-FR", "es-ES"]

  defp request_id_gen do
    gen all(suffix <- string(:alphanumeric, min_length: 4, max_length: 16)) do
      "amzn1.echo-api.request.#{suffix}"
    end
  end

  defp timestamp_gen do
    gen all(
          year <- integer(2024..2027),
          month <- integer(1..12),
          day <- integer(1..28),
          hour <- integer(0..23),
          minute <- integer(0..59),
          second <- integer(0..59)
        ) do
      month_s = String.pad_leading("#{month}", 2, "0")
      day_s = String.pad_leading("#{day}", 2, "0")
      hour_s = String.pad_leading("#{hour}", 2, "0")
      min_s = String.pad_leading("#{minute}", 2, "0")
      sec_s = String.pad_leading("#{second}", 2, "0")
      "#{year}-#{month_s}-#{day_s}T#{hour_s}:#{min_s}:#{sec_s}Z"
    end
  end

  defp locale_gen, do: member_of(@locales)

  defp session_gen do
    constant(%{
      "new" => true,
      "sessionId" => "amzn1.echo-api.session.prop",
      "application" => %{"applicationId" => "amzn1.ask.skill.prop"},
      "user" => %{"userId" => "amzn1.ask.account.prop"},
      "attributes" => %{}
    })
  end

  defp context_gen do
    constant(%{
      "System" => %{
        "application" => %{"applicationId" => "amzn1.ask.skill.prop"},
        "user" => %{"userId" => "amzn1.ask.account.prop"},
        "device" => %{"deviceId" => "amzn1.ask.device.prop", "supportedInterfaces" => %{}},
        "apiEndpoint" => "https://api.amazonalexa.com",
        "apiAccessToken" => "fake.token"
      }
    })
  end

  defp launch_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          session <- session_gen(),
          context <- context_gen()
        ) do
      %{
        "version" => "1.0",
        "session" => session,
        "context" => context,
        "request" => %{
          "type" => "LaunchRequest",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale
        }
      }
    end
  end

  defp intent_name_gen do
    gen all(name <- string(:alphanumeric, min_length: 3, max_length: 20)) do
      "#{name}Intent"
    end
  end

  defp dialog_state_gen, do: member_of(["STARTED", "IN_PROGRESS", "COMPLETED"])

  defp slot_gen do
    gen all(
          name <- string(:alphanumeric, min_length: 2, max_length: 12),
          value <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      {name,
       %{
         "name" => name,
         "value" => value,
         "confirmationStatus" => "NONE"
       }}
    end
  end

  defp intent_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          session <- session_gen(),
          context <- context_gen(),
          intent_name <- intent_name_gen(),
          dialog_state <- dialog_state_gen(),
          slots <- list_of(slot_gen(), min_length: 0, max_length: 3)
        ) do
      %{
        "version" => "1.0",
        "session" => session,
        "context" => context,
        "request" => %{
          "type" => "IntentRequest",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale,
          "dialogState" => dialog_state,
          "intent" => %{
            "name" => intent_name,
            "confirmationStatus" => "NONE",
            "slots" => Map.new(slots)
          }
        }
      }
    end
  end

  defp session_ended_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          session <- session_gen(),
          context <- context_gen(),
          reason <- member_of(["USER_INITIATED", "ERROR", "EXCEEDED_MAX_REPROMPTS"])
        ) do
      %{
        "version" => "1.0",
        "session" => session,
        "context" => context,
        "request" => %{
          "type" => "SessionEndedRequest",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale,
          "reason" => reason
        }
      }
    end
  end

  defp audio_event_gen,
    do: member_of(["PlaybackStarted", "PlaybackFinished", "PlaybackStopped", "PlaybackNearlyFinished"])

  defp audio_player_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          context <- context_gen(),
          event <- audio_event_gen(),
          token <- string(:alphanumeric, min_length: 3, max_length: 12),
          offset <- integer(0..300_000)
        ) do
      %{
        "version" => "1.0",
        "context" => context,
        "request" => %{
          "type" => "AudioPlayer.#{event}",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale,
          "token" => token,
          "offsetInMilliseconds" => offset
        }
      }
    end
  end

  defp playback_controller_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          context <- context_gen(),
          command <-
            member_of([
              "PlayCommandIssued",
              "PauseCommandIssued",
              "NextCommandIssued",
              "PreviousCommandIssued",
              "ResumeCommandIssued"
            ])
        ) do
      %{
        "version" => "1.0",
        "context" => context,
        "request" => %{
          "type" => "PlaybackController.#{command}",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale
        }
      }
    end
  end

  defp system_exception_request_gen do
    gen all(
          req_id <- request_id_gen(),
          ts <- timestamp_gen(),
          locale <- locale_gen(),
          context <- context_gen(),
          error_type <- member_of(["INVALID_RESPONSE", "INTERNAL_SERVICE_ERROR", "DEVICE_COMMUNICATION_ERROR"]),
          error_msg <- string(:alphanumeric, min_length: 5, max_length: 40)
        ) do
      %{
        "version" => "1.0",
        "context" => context,
        "request" => %{
          "type" => "System.ExceptionEncountered",
          "requestId" => req_id,
          "timestamp" => ts,
          "locale" => locale,
          "error" => %{"type" => error_type, "message" => error_msg},
          "cause" => %{"requestId" => "amzn1.echo-api.request.prev"}
        }
      }
    end
  end

  # ── Properties ──────────────────────────────────────────────────────────

  property "LaunchRequest round-trips through parser" do
    check all(raw <- launch_request_gen()) do
      assert {:ok, %Request{request: %Request.Launch{} = inner}} = Request.from_map(raw)
      assert inner.request_id == raw["request"]["requestId"]
      assert inner.locale == raw["request"]["locale"]
    end
  end

  property "IntentRequest round-trips through parser" do
    check all(raw <- intent_request_gen()) do
      assert {:ok, %Request{request: %Request.Intent{} = inner}} = Request.from_map(raw)
      assert inner.intent.name == raw["request"]["intent"]["name"]

      for {slot_name, slot_raw} <- raw["request"]["intent"]["slots"] do
        assert inner.intent.slots[slot_name].value == slot_raw["value"]
      end
    end
  end

  property "SessionEndedRequest round-trips through parser" do
    check all(raw <- session_ended_request_gen()) do
      assert {:ok, %Request{request: %Request.SessionEnded{}}} = Request.from_map(raw)
    end
  end

  property "AudioPlayer events round-trip through parser" do
    check all(raw <- audio_player_request_gen()) do
      assert {:ok, %Request{request: %Request.AudioPlayer{} = inner}} = Request.from_map(raw)
      assert inner.token == raw["request"]["token"]
      assert inner.offset_in_milliseconds == raw["request"]["offsetInMilliseconds"]
    end
  end

  property "PlaybackController commands round-trip through parser" do
    check all(raw <- playback_controller_request_gen()) do
      assert {:ok, %Request{request: %Request.PlaybackController{} = inner}} = Request.from_map(raw)
      assert inner.request_id == raw["request"]["requestId"]
      assert inner.command in [:play, :pause, :next, :previous, :resume]
    end
  end

  property "System.ExceptionEncountered round-trips through parser" do
    check all(raw <- system_exception_request_gen()) do
      assert {:ok, %Request{request: %Request.SystemException{} = inner}} = Request.from_map(raw)
      assert inner.error.type == raw["request"]["error"]["type"]
      assert inner.error.message == raw["request"]["error"]["message"]
    end
  end
end
