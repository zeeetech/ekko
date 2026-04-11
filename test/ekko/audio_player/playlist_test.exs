defmodule Ekko.AudioPlayer.PlaylistTest do
  use ExUnit.Case, async: true

  alias Ekko.AudioPlayer.Playlist

  defp tracks do
    [
      %{token: "t1", url: "https://example.com/1.mp3", title: "Song 1", subtitle: nil, art_url: nil, duration_ms: nil},
      %{token: "t2", url: "https://example.com/2.mp3", title: "Song 2", subtitle: nil, art_url: nil, duration_ms: nil},
      %{token: "t3", url: "https://example.com/3.mp3", title: "Song 3", subtitle: nil, art_url: nil, duration_ms: nil}
    ]
  end

  describe "new/2" do
    test "creates a playlist at cursor 0" do
      pl = Playlist.new(tracks())
      assert pl.cursor == 0
      assert length(pl.tracks) == 3
      assert pl.loop == :off
    end
  end

  describe "current/1" do
    test "returns the track at the cursor" do
      pl = Playlist.new(tracks())
      assert Playlist.current(pl).token == "t1"
    end

    test "returns nil for empty playlist" do
      assert Playlist.current(Playlist.new([])) == nil
    end
  end

  describe "next/1" do
    test "advances the cursor" do
      pl = Playlist.new(tracks())
      assert {:ok, pl, track} = Playlist.next(pl)
      assert track.token == "t2"
      assert Playlist.current(pl).token == "t2"
    end

    test "returns :end_of_playlist at the tail with loop: :off" do
      pl = Playlist.new(tracks(), cursor: 2)
      assert :end_of_playlist = Playlist.next(pl)
    end

    test "wraps with loop: :all" do
      pl = Playlist.new(tracks(), cursor: 2, loop: :all)
      assert {:ok, pl, track} = Playlist.next(pl)
      assert track.token == "t1"
      assert pl.cursor == 0
    end

    test "re-returns current with loop: :one" do
      pl = Playlist.new(tracks(), cursor: 1, loop: :one)
      assert {:ok, ^pl, track} = Playlist.next(pl)
      assert track.token == "t2"
    end

    test "returns :end_of_playlist for empty" do
      assert :end_of_playlist = Playlist.next(Playlist.new([]))
    end
  end

  describe "previous/1" do
    test "moves cursor backward" do
      pl = Playlist.new(tracks(), cursor: 2)
      assert {:ok, pl, track} = Playlist.previous(pl)
      assert track.token == "t2"
      assert pl.cursor == 1
    end

    test "returns :start_of_playlist at head with loop: :off" do
      pl = Playlist.new(tracks())
      assert :start_of_playlist = Playlist.previous(pl)
    end

    test "wraps with loop: :all" do
      pl = Playlist.new(tracks(), loop: :all)
      assert {:ok, pl, track} = Playlist.previous(pl)
      assert track.token == "t3"
      assert pl.cursor == 2
    end

    test "returns :start_of_playlist for empty" do
      assert :start_of_playlist = Playlist.previous(Playlist.new([]))
    end
  end

  describe "advance_to_token/2" do
    test "moves cursor to matching track" do
      pl = Playlist.new(tracks())
      assert {:ok, pl} = Playlist.advance_to_token(pl, "t3")
      assert Playlist.current(pl).token == "t3"
    end

    test "returns :not_found for missing token" do
      pl = Playlist.new(tracks())
      assert :not_found = Playlist.advance_to_token(pl, "t999")
    end
  end

  describe "shuffle/2" do
    test "toggle on preserves current track" do
      pl = Playlist.new(tracks(), cursor: 1)
      current_before = Playlist.current(pl)
      shuffled = Playlist.shuffle(pl, true)
      assert shuffled.shuffled == true
      assert Playlist.current(shuffled).token == current_before.token
    end

    test "toggle off preserves current track" do
      pl = tracks() |> Playlist.new(cursor: 1) |> Playlist.shuffle(true)
      current_before = Playlist.current(pl)
      unshuffled = Playlist.shuffle(pl, false)
      assert unshuffled.shuffled == false
      assert unshuffled.shuffle_order == nil
      assert Playlist.current(unshuffled).token == current_before.token
    end
  end

  describe "set_loop/2" do
    test "sets loop mode" do
      pl = Playlist.new(tracks())
      assert Playlist.set_loop(pl, :all).loop == :all
      assert Playlist.set_loop(pl, :one).loop == :one
      assert Playlist.set_loop(pl, :off).loop == :off
    end
  end

  describe "append/2" do
    test "adds tracks to end" do
      pl = Playlist.new(tracks())

      new_track = %{
        token: "t4",
        url: "https://example.com/4.mp3",
        title: nil,
        subtitle: nil,
        art_url: nil,
        duration_ms: nil
      }

      pl = Playlist.append(pl, [new_track])
      assert length(pl.tracks) == 4
      assert List.last(pl.tracks).token == "t4"
    end
  end

  describe "remove/2" do
    test "removes track by token" do
      pl = Playlist.new(tracks())
      pl = Playlist.remove(pl, "t2")
      assert length(pl.tracks) == 2
      refute Enum.any?(pl.tracks, &(&1.token == "t2"))
    end

    test "adjusts cursor when removing before current" do
      pl = Playlist.new(tracks(), cursor: 2)
      pl = Playlist.remove(pl, "t1")
      assert Playlist.current(pl).token == "t3"
    end

    test "no-op for missing token" do
      pl = Playlist.new(tracks())
      assert Playlist.remove(pl, "t999") == pl
    end
  end
end
