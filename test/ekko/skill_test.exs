defmodule Ekko.SkillTest do
  use ExUnit.Case, async: true

  alias Ekko.Test.Fixtures

  defmodule EmptySkill do
    @moduledoc false
    use Ekko.Skill
  end

  defmodule TestSkill do
    @moduledoc false
    use Ekko.Skill

    alias Ekko.Request

    @impl Ekko.Skill
    def handle_request(%Request.Launch{}, ekko) do
      response = ekko |> Ekko.speak("welcome") |> Ekko.build()
      {:ok, response}
    end

    def handle_request(%Request.Intent{intent: %{name: "PlayMusicIntent"}}, ekko) do
      song =
        ekko.request.request.intent.slots
        |> Map.get("songName", %{})
        |> Map.get(:value, "default")

      response =
        ekko
        |> Ekko.speak("playing #{song}")
        |> Ekko.add_audio_player_play(:replace_all, "https://x/#{song}.mp3", "tok-1", 0)
        |> Ekko.build()

      {:ok, response}
    end

    def handle_request(%Request.Intent{intent: %{name: "BoomIntent"}}, _ekko) do
      {:error, :boom}
    end

    @impl Ekko.Skill
    def handle_error(:boom, _request, ekko) do
      response = ekko |> Ekko.speak("recovered") |> Ekko.build()
      {:ok, response}
    end

    def handle_error(error, _request, _ekko), do: {:error, error}
  end

  defmodule MinimalSkill do
    @moduledoc false
    use Ekko.Skill

    @impl Ekko.Skill
    def handle_request(_request, ekko) do
      {:ok, Ekko.build(ekko)}
    end
  end

  describe "Ekko.handle/2" do
    test "dispatches LaunchRequest" do
      assert {:ok, response} = Ekko.handle(TestSkill, Fixtures.launch_request())
      assert response["response"]["outputSpeech"]["text"] == "welcome"
    end

    test "dispatches IntentRequest with slot value" do
      assert {:ok, response} = Ekko.handle(TestSkill, Fixtures.intent_request())
      assert response["response"]["outputSpeech"]["text"] == "playing starlight"

      assert [%{"type" => "AudioPlayer.Play", "audioItem" => %{"stream" => %{"url" => url}}}] =
               response["response"]["directives"]

      assert url == "https://x/starlight.mp3"
    end

    test "dispatches AudioPlayer event with no session" do
      assert {:ok, response} = Ekko.handle(MinimalSkill, Fixtures.audio_player_playback_started())
      assert response == %{"version" => "1.0", "response" => %{}}
    end

    test "unhandled request falls through to the injected catch-all" do
      assert {:error, :no_handler_match} = Ekko.handle(EmptySkill, Fixtures.launch_request())
    end

    test "handle_error/3 recovers from a handler error" do
      raw = put_in(Fixtures.intent_request(), ["request", "intent", "name"], "BoomIntent")

      assert {:ok, response} = Ekko.handle(TestSkill, raw)
      assert response["response"]["outputSpeech"]["text"] == "recovered"
    end

    test "default handle_error propagates the error" do
      raw = put_in(Fixtures.intent_request(), ["request", "intent", "name"], "UnknownIntent")

      assert {:error, :no_handler_match} = Ekko.handle(TestSkill, raw)
    end

    test "invalid raw request bubbles up the parser error" do
      assert {:error, :invalid_request} = Ekko.handle(TestSkill, %{})
    end
  end
end
