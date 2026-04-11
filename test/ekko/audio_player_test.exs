defmodule Ekko.AudioPlayerTest do
  use ExUnit.Case, async: false

  alias Ekko.AudioPlayer
  alias Ekko.AudioPlayer.Playlist
  alias Ekko.Test.Fixtures

  defp ekko do
    {:ok, request} = Ekko.Request.from_map(Fixtures.launch_request())
    Ekko.new(request)
  end

  defp sample_tracks do
    [
      %{token: "t1", url: "https://example.com/1.mp3", title: "Song 1", subtitle: nil, art_url: nil, duration_ms: nil},
      %{token: "t2", url: "https://example.com/2.mp3", title: "Song 2", subtitle: nil, art_url: nil, duration_ms: nil},
      %{token: "t3", url: "https://example.com/3.mp3", title: "Song 3", subtitle: nil, art_url: nil, duration_ms: nil}
    ]
  end

  describe "play_current/2" do
    test "builds AudioPlayer.Play directive from current track" do
      pl = Playlist.new(sample_tracks())
      result = ekko() |> AudioPlayer.play_current(pl) |> Ekko.build()
      [directive] = result["response"]["directives"]

      assert directive["type"] == "AudioPlayer.Play"
      assert directive["playBehavior"] == "REPLACE_ALL"
      assert directive["audioItem"]["stream"]["url"] == "https://example.com/1.mp3"
      assert directive["audioItem"]["stream"]["token"] == "t1"
    end

    test "no-op for empty playlist" do
      pl = Playlist.new([])
      result = ekko() |> AudioPlayer.play_current(pl) |> Ekko.build()
      assert result["response"]["directives"] == nil
    end
  end

  describe "play_next/2" do
    test "advances and builds directive" do
      pl = Playlist.new(sample_tracks())
      {ekko, pl} = AudioPlayer.play_next(ekko(), pl)

      result = Ekko.build(ekko)
      [directive] = result["response"]["directives"]
      assert directive["audioItem"]["stream"]["token"] == "t2"
      assert Playlist.current(pl).token == "t2"
    end

    test "returns :end_of_playlist at tail" do
      pl = Playlist.new(sample_tracks(), cursor: 2)
      assert :end_of_playlist = AudioPlayer.play_next(ekko(), pl)
    end
  end

  describe "play_previous/2" do
    test "goes back and builds directive" do
      pl = Playlist.new(sample_tracks(), cursor: 2)
      {ekko, pl} = AudioPlayer.play_previous(ekko(), pl)

      result = Ekko.build(ekko)
      [directive] = result["response"]["directives"]
      assert directive["audioItem"]["stream"]["token"] == "t2"
      assert Playlist.current(pl).token == "t2"
    end

    test "returns :start_of_playlist at head" do
      pl = Playlist.new(sample_tracks())
      assert :start_of_playlist = AudioPlayer.play_previous(ekko(), pl)
    end
  end

  describe "enqueue_next/2" do
    test "enqueues with expected_previous_token" do
      pl = Playlist.new(sample_tracks())
      result = ekko() |> AudioPlayer.enqueue_next(pl) |> Ekko.build()
      [directive] = result["response"]["directives"]

      assert directive["type"] == "AudioPlayer.Play"
      assert directive["playBehavior"] == "ENQUEUE"
      assert directive["audioItem"]["stream"]["token"] == "t2"
      assert directive["audioItem"]["stream"]["expectedPreviousToken"] == "t1"
    end

    test "no-op at end of playlist" do
      pl = Playlist.new(sample_tracks(), cursor: 2)
      result = ekko() |> AudioPlayer.enqueue_next(pl) |> Ekko.build()
      assert result["response"]["directives"] == nil
    end
  end

  describe "stop_playback/1" do
    test "builds AudioPlayer.Stop directive" do
      result = ekko() |> AudioPlayer.stop_playback() |> Ekko.build()
      [directive] = result["response"]["directives"]
      assert directive["type"] == "AudioPlayer.Stop"
    end
  end

  describe "clear_and_play/2" do
    test "clears queue then plays current" do
      pl = Playlist.new(sample_tracks())
      result = ekko() |> AudioPlayer.clear_and_play(pl) |> Ekko.build()
      directives = result["response"]["directives"]

      assert length(directives) == 2
      assert Enum.at(directives, 0)["type"] == "AudioPlayer.ClearQueue"
      assert Enum.at(directives, 1)["type"] == "AudioPlayer.Play"
    end
  end

  describe "store operations" do
    setup do
      :ets.delete_all_objects(:ekko_audio_player_playlists)
      :ok
    end

    test "load/save/clear round-trip" do
      pl = Playlist.new(sample_tracks())
      user = "amzn1.ask.account.test"

      assert {:ok, nil} = AudioPlayer.load(user)
      assert :ok = AudioPlayer.save(user, pl)
      assert {:ok, ^pl} = AudioPlayer.load(user)
      assert :ok = AudioPlayer.clear(user)
      assert {:ok, nil} = AudioPlayer.load(user)
    end
  end
end
