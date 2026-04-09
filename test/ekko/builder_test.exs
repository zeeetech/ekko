defmodule Ekko.BuilderTest do
  use ExUnit.Case, async: true

  alias Ekko.Test.Fixtures

  defp ekko do
    {:ok, request} = Ekko.Request.from_map(Fixtures.launch_request())
    Ekko.new(request)
  end

  describe "speak/2" do
    test "plain text becomes PlainText output speech" do
      response = ekko() |> Ekko.speak("hello") |> Ekko.build()
      assert response["response"]["outputSpeech"] == %{"type" => "PlainText", "text" => "hello"}
    end

    test "<speak>...</speak> is preserved as SSML" do
      response = ekko() |> Ekko.speak("<speak>hi</speak>") |> Ekko.build()
      assert response["response"]["outputSpeech"] == %{"type" => "SSML", "ssml" => "<speak>hi</speak>"}
    end

    test "bare SSML markup is auto-wrapped in <speak>" do
      response = ekko() |> Ekko.speak("<emphasis>foo</emphasis>") |> Ekko.build()

      assert response["response"]["outputSpeech"] == %{
               "type" => "SSML",
               "ssml" => "<speak><emphasis>foo</emphasis></speak>"
             }
    end
  end

  describe "reprompt/2" do
    test "wraps the speech in an outputSpeech key" do
      response = ekko() |> Ekko.reprompt("are you there?") |> Ekko.build()

      assert response["response"]["reprompt"] == %{
               "outputSpeech" => %{"type" => "PlainText", "text" => "are you there?"}
             }
    end
  end

  describe "card/3..5" do
    test "simple card" do
      response = ekko() |> Ekko.card(:simple, "Welcome", "Hello!") |> Ekko.build()

      assert response["response"]["card"] == %{
               "type" => "Simple",
               "title" => "Welcome",
               "content" => "Hello!"
             }
    end

    test "standard card without image" do
      response = ekko() |> Ekko.card(:standard, "T", "body") |> Ekko.build()

      assert response["response"]["card"] == %{
               "type" => "Standard",
               "title" => "T",
               "text" => "body"
             }
    end

    test "standard card with both image sizes" do
      response =
        ekko()
        |> Ekko.card(:standard, "T", "body", %{small: "https://x/s.png", large: "https://x/l.png"})
        |> Ekko.build()

      assert response["response"]["card"]["image"] == %{
               "smallImageUrl" => "https://x/s.png",
               "largeImageUrl" => "https://x/l.png"
             }
    end

    test "link account card" do
      response = ekko() |> Ekko.link_account_card() |> Ekko.build()
      assert response["response"]["card"] == %{"type" => "LinkAccount"}
    end

    test "ask for permissions card" do
      response =
        ekko()
        |> Ekko.ask_for_permissions_card(["alexa::devices:all:address:full:read"])
        |> Ekko.build()

      assert response["response"]["card"] == %{
               "type" => "AskForPermissionsConsent",
               "permissions" => ["alexa::devices:all:address:full:read"]
             }
    end
  end

  describe "should_end_session/2 and with_session_attributes/2" do
    test "should_end_session true and false propagate" do
      assert ekko() |> Ekko.should_end_session(true) |> Ekko.build() |> get_in(["response", "shouldEndSession"]) == true
      assert ekko() |> Ekko.should_end_session(false) |> Ekko.build() |> get_in(["response", "shouldEndSession"]) == false
    end

    test "session attributes write to top-level sessionAttributes" do
      response = ekko() |> Ekko.with_session_attributes(%{"counter" => 1}) |> Ekko.build()
      assert response["sessionAttributes"] == %{"counter" => 1}
    end
  end

  describe "AudioPlayer directives" do
    test "play with replace_all and minimal opts" do
      response =
        ekko()
        |> Ekko.add_audio_player_play(:replace_all, "https://x/s.mp3", "tok-1", 0)
        |> Ekko.build()

      assert [directive] = response["response"]["directives"]
      assert directive["type"] == "AudioPlayer.Play"
      assert directive["playBehavior"] == "REPLACE_ALL"
      assert directive["audioItem"]["stream"]["url"] == "https://x/s.mp3"
      assert directive["audioItem"]["stream"]["token"] == "tok-1"
      assert directive["audioItem"]["stream"]["offsetInMilliseconds"] == 0
      refute Map.has_key?(directive["audioItem"]["stream"], "expectedPreviousToken")
      refute Map.has_key?(directive["audioItem"], "metadata")
    end

    test "play with enqueue, expected previous token, and metadata" do
      response =
        ekko()
        |> Ekko.add_audio_player_play(:enqueue, "https://x/s.mp3", "tok-2", 0,
          expected_previous_token: "tok-1",
          metadata: %{title: "Song", subtitle: "Artist", art: "https://x/art.png"}
        )
        |> Ekko.build()

      [directive] = response["response"]["directives"]
      assert directive["playBehavior"] == "ENQUEUE"
      assert directive["audioItem"]["stream"]["expectedPreviousToken"] == "tok-1"
      assert directive["audioItem"]["metadata"]["title"] == "Song"
      assert directive["audioItem"]["metadata"]["subtitle"] == "Artist"
      assert directive["audioItem"]["metadata"]["art"]["sources"] == [%{"url" => "https://x/art.png"}]
    end

    test "stop directive" do
      response = ekko() |> Ekko.add_audio_player_stop() |> Ekko.build()
      assert response["response"]["directives"] == [%{"type" => "AudioPlayer.Stop"}]
    end

    test "clear queue with both behaviors" do
      assert ekko()
             |> Ekko.add_audio_player_clear_queue(:clear_enqueued)
             |> Ekko.build()
             |> get_in(["response", "directives"]) == [
               %{"type" => "AudioPlayer.ClearQueue", "clearBehavior" => "CLEAR_ENQUEUED"}
             ]

      assert ekko()
             |> Ekko.add_audio_player_clear_queue(:clear_all)
             |> Ekko.build()
             |> get_in(["response", "directives"]) == [
               %{"type" => "AudioPlayer.ClearQueue", "clearBehavior" => "CLEAR_ALL"}
             ]
    end
  end

  describe "Dialog directives" do
    test "delegate" do
      response = ekko() |> Ekko.add_delegate_directive() |> Ekko.build()
      assert response["response"]["directives"] == [%{"type" => "Dialog.Delegate"}]
    end

    test "elicit slot" do
      response = ekko() |> Ekko.add_elicit_slot_directive("songName") |> Ekko.build()

      assert response["response"]["directives"] == [
               %{"type" => "Dialog.ElicitSlot", "slotToElicit" => "songName"}
             ]
    end

    test "confirm slot" do
      response = ekko() |> Ekko.add_confirm_slot_directive("songName") |> Ekko.build()

      assert response["response"]["directives"] == [
               %{"type" => "Dialog.ConfirmSlot", "slotToConfirm" => "songName"}
             ]
    end

    test "confirm intent" do
      response = ekko() |> Ekko.add_confirm_intent_directive() |> Ekko.build()
      assert response["response"]["directives"] == [%{"type" => "Dialog.ConfirmIntent"}]
    end
  end

  describe "build/1" do
    test "minimal envelope drops nil fields" do
      response = Ekko.build(ekko())
      assert response == %{"version" => "1.0", "response" => %{}}
    end

    test "full envelope round-trips through JSON encode" do
      response =
        ekko()
        |> Ekko.speak("hi")
        |> Ekko.card(:simple, "t", "c")
        |> Ekko.reprompt("?")
        |> Ekko.should_end_session(false)
        |> Ekko.with_session_attributes(%{"a" => 1})
        |> Ekko.build()

      assert json = JSON.encode!(response)
      assert ^response = JSON.decode!(json)
    end
  end
end
