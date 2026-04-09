defmodule Ekko.RequestTest do
  use ExUnit.Case, async: true

  alias Ekko.Request
  alias Ekko.Request.AudioPlayer
  alias Ekko.Request.Intent
  alias Ekko.Request.Launch
  alias Ekko.Request.Session
  alias Ekko.Request.SessionEnded
  alias Ekko.Test.Fixtures

  describe "from_map/1 with LaunchRequest" do
    test "parses envelope, session, context, and request" do
      assert {:ok, env} = Request.from_map(Fixtures.launch_request())

      assert %Request{
               version: "1.0",
               session: %Session{new?: true, session_id: "amzn1.echo-api.session.0000"},
               request: %Launch{
                 request_id: "amzn1.echo-api.request.0000-launch",
                 locale: "en-US"
               }
             } = env

      assert %DateTime{} = env.request.timestamp
      assert env.context.system.api_endpoint == "https://api.amazonalexa.com"
      assert env.context.audio_player.player_activity == :idle
    end
  end

  describe "from_map/1 with IntentRequest" do
    test "parses intent name, dialog state, and slots" do
      assert {:ok, env} = Request.from_map(Fixtures.intent_request())

      assert %Intent{
               dialog_state: :started,
               intent: %{name: "PlayMusicIntent", confirmation_status: :none, slots: slots}
             } = env.request

      assert %{"songName" => slot} = slots
      assert slot.name == "songName"
      assert slot.value == "starlight"
      assert slot.confirmation_status == :none
    end
  end

  describe "from_map/1 with SessionEndedRequest" do
    test "parses reason as atom" do
      assert {:ok, env} = Request.from_map(Fixtures.session_ended_request())
      assert %SessionEnded{reason: :user_initiated} = env.request
    end
  end

  describe "from_map/1 with AudioPlayer events" do
    test "PlaybackStarted parses with no session" do
      assert {:ok, env} = Request.from_map(Fixtures.audio_player_playback_started())

      assert env.session == nil
      assert %AudioPlayer{event: :started, token: "track-001", offset_in_milliseconds: 0} = env.request
    end

    test "PlaybackNearlyFinished parses event tag" do
      assert {:ok, env} = Request.from_map(Fixtures.audio_player_playback_nearly_finished())

      assert %AudioPlayer{event: :nearly_finished, offset_in_milliseconds: 175_000} = env.request
    end

    test "PlaybackFailed nests error and current playback state" do
      assert {:ok, env} = Request.from_map(Fixtures.audio_player_playback_failed())

      assert %AudioPlayer{
               event: :failed,
               error: %{type: "MEDIA_ERROR_INTERNAL_DEVICE_ERROR", message: msg},
               current_playback_state: %{token: "track-001", player_activity: :playing}
             } = env.request

      assert msg =~ "decode"
    end
  end

  describe "from_map/1 error paths" do
    test "missing required envelope keys" do
      assert {:error, :invalid_request} = Request.from_map(%{})
    end

    test "unknown request type" do
      raw = %{
        "version" => "1.0",
        "context" => %{},
        "request" => %{"type" => "Bogus.Request"}
      }

      assert {:error, {:unknown_request_type, "Bogus.Request"}} = Request.from_map(raw)
    end

    test "invalid timestamp on LaunchRequest" do
      raw = put_in(Fixtures.launch_request(), ["request", "timestamp"], "not-a-date")

      assert {:error, :invalid_timestamp} = Request.from_map(raw)
    end
  end
end
