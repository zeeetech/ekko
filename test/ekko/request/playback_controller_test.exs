defmodule Ekko.Request.PlaybackControllerTest do
  use ExUnit.Case, async: true

  alias Ekko.Request
  alias Ekko.Request.PlaybackController
  alias Ekko.Test.Fixtures

  describe "from_map/1" do
    for {type_suffix, command} <- [
          {"PlayCommandIssued", :play},
          {"PauseCommandIssued", :pause},
          {"NextCommandIssued", :next},
          {"PreviousCommandIssued", :previous},
          {"ResumeCommandIssued", :resume}
        ] do
      test "parses #{type_suffix} as :#{command}" do
        raw = %{
          "type" => "PlaybackController.#{unquote(type_suffix)}",
          "requestId" => "req-123",
          "timestamp" => "2026-04-09T10:00:00Z",
          "locale" => "en-US"
        }

        assert {:ok, %PlaybackController{command: unquote(command)}} = PlaybackController.from_map(raw)
      end
    end

    test "preserves locale and timestamp" do
      raw = %{
        "type" => "PlaybackController.NextCommandIssued",
        "requestId" => "req-456",
        "timestamp" => "2026-04-09T12:30:00Z",
        "locale" => "pt-BR"
      }

      assert {:ok, %PlaybackController{locale: "pt-BR", request_id: "req-456"} = pc} =
               PlaybackController.from_map(raw)

      assert pc.timestamp == ~U[2026-04-09 12:30:00Z]
    end

    test "rejects unknown subtype" do
      raw = %{
        "type" => "PlaybackController.SkipCommandIssued",
        "requestId" => "req-789",
        "timestamp" => "2026-04-09T10:00:00Z"
      }

      assert {:error, {:unknown_playback_controller_command, "SkipCommandIssued"}} =
               PlaybackController.from_map(raw)
    end

    test "rejects missing fields" do
      assert {:error, _} = PlaybackController.from_map(%{"type" => "PlaybackController.NextCommandIssued"})
    end
  end

  describe "Request.from_map/1 dispatch" do
    test "dispatches PlaybackController.NextCommandIssued" do
      assert {:ok, %Request{request: %PlaybackController{command: :next}}} =
               Request.from_map(Fixtures.playback_controller_next())
    end

    test "dispatches PlaybackController.PlayCommandIssued" do
      assert {:ok, %Request{request: %PlaybackController{command: :play}}} =
               Request.from_map(Fixtures.playback_controller_play())
    end
  end
end
