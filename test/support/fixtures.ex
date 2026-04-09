defmodule Ekko.Test.Fixtures do
  @moduledoc """
  Decoded-JSON request fixtures used by parser tests, modeled after the
  examples in Amazon's
  [request and response JSON reference](https://developer.amazon.com/docs/custom-skills/request-and-response-json-reference.html).

  Each function returns a plain Elixir map with hardcoded camelCase string
  keys — what `JSON.decode!/1` would produce on a real Alexa request body.
  """

  @spec launch_request() :: map()
  def launch_request do
    %{
      "version" => "1.0",
      "session" => session(),
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "LaunchRequest",
        "requestId" => "amzn1.echo-api.request.0000-launch",
        "timestamp" => "2026-04-09T10:00:00Z",
        "locale" => "en-US"
      }
    }
  end

  @spec intent_request() :: map()
  def intent_request do
    %{
      "version" => "1.0",
      "session" => session(),
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "IntentRequest",
        "requestId" => "amzn1.echo-api.request.0000-intent",
        "timestamp" => "2026-04-09T10:00:01Z",
        "locale" => "en-US",
        "dialogState" => "STARTED",
        "intent" => %{
          "name" => "PlayMusicIntent",
          "confirmationStatus" => "NONE",
          "slots" => %{
            "songName" => %{
              "name" => "songName",
              "value" => "starlight",
              "confirmationStatus" => "NONE"
            }
          }
        }
      }
    }
  end

  @spec session_ended_request() :: map()
  def session_ended_request do
    %{
      "version" => "1.0",
      "session" => session(),
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "SessionEndedRequest",
        "requestId" => "amzn1.echo-api.request.0000-end",
        "timestamp" => "2026-04-09T10:00:02Z",
        "locale" => "en-US",
        "reason" => "USER_INITIATED"
      }
    }
  end

  @spec audio_player_playback_started() :: map()
  def audio_player_playback_started do
    %{
      "version" => "1.0",
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "AudioPlayer.PlaybackStarted",
        "requestId" => "amzn1.echo-api.request.0000-ap-started",
        "timestamp" => "2026-04-09T10:00:03Z",
        "locale" => "en-US",
        "token" => "track-001",
        "offsetInMilliseconds" => 0
      }
    }
  end

  @spec audio_player_playback_nearly_finished() :: map()
  def audio_player_playback_nearly_finished do
    %{
      "version" => "1.0",
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "AudioPlayer.PlaybackNearlyFinished",
        "requestId" => "amzn1.echo-api.request.0000-ap-nearly",
        "timestamp" => "2026-04-09T10:00:04Z",
        "locale" => "en-US",
        "token" => "track-001",
        "offsetInMilliseconds" => 175_000
      }
    }
  end

  @spec audio_player_playback_failed() :: map()
  def audio_player_playback_failed do
    %{
      "version" => "1.0",
      "context" => context_with_audio_state(),
      "request" => %{
        "type" => "AudioPlayer.PlaybackFailed",
        "requestId" => "amzn1.echo-api.request.0000-ap-failed",
        "timestamp" => "2026-04-09T10:00:05Z",
        "locale" => "en-US",
        "token" => "track-001",
        "offsetInMilliseconds" => 12_345,
        "error" => %{
          "type" => "MEDIA_ERROR_INTERNAL_DEVICE_ERROR",
          "message" => "Device cannot decode the stream"
        },
        "currentPlaybackState" => %{
          "token" => "track-001",
          "offsetInMilliseconds" => 12_345,
          "playerActivity" => "PLAYING"
        }
      }
    }
  end

  defp session do
    %{
      "new" => true,
      "sessionId" => "amzn1.echo-api.session.0000",
      "application" => %{"applicationId" => "amzn1.ask.skill.0000"},
      "user" => %{"userId" => "amzn1.ask.account.0000"},
      "attributes" => %{}
    }
  end

  defp context_with_audio_state do
    %{
      "System" => %{
        "application" => %{"applicationId" => "amzn1.ask.skill.0000"},
        "user" => %{"userId" => "amzn1.ask.account.0000"},
        "device" => %{"deviceId" => "amzn1.ask.device.0000", "supportedInterfaces" => %{}},
        "apiEndpoint" => "https://api.amazonalexa.com",
        "apiAccessToken" => "fake.access.token"
      },
      "AudioPlayer" => %{
        "token" => "track-001",
        "offsetInMilliseconds" => 0,
        "playerActivity" => "IDLE"
      }
    }
  end
end
