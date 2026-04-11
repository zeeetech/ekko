defmodule Ekko.AudioPlayer.PlaylistStore.ETSTest do
  use ExUnit.Case, async: false

  alias Ekko.AudioPlayer.Playlist
  alias Ekko.AudioPlayer.PlaylistStore.ETS

  setup do
    :ets.delete_all_objects(:ekko_audio_player_playlists)
    :ok
  end

  test "put/get round-trip" do
    pl =
      Playlist.new([
        %{token: "t1", url: "https://example.com/1.mp3", title: nil, subtitle: nil, art_url: nil, duration_ms: nil}
      ])

    assert :ok = ETS.put("user-a", pl)
    assert {:ok, ^pl} = ETS.get("user-a")
  end

  test "get returns nil for missing key" do
    assert {:ok, nil} = ETS.get("nonexistent-user")
  end

  test "delete removes the entry" do
    pl = Playlist.new([])
    ETS.put("user-b", pl)
    assert :ok = ETS.delete("user-b")
    assert {:ok, nil} = ETS.get("user-b")
  end

  test "user isolation" do
    pl_a =
      Playlist.new([
        %{token: "a1", url: "https://a.com/1.mp3", title: nil, subtitle: nil, art_url: nil, duration_ms: nil}
      ])

    pl_b =
      Playlist.new([
        %{token: "b1", url: "https://b.com/1.mp3", title: nil, subtitle: nil, art_url: nil, duration_ms: nil}
      ])

    ETS.put("user-a", pl_a)
    ETS.put("user-b", pl_b)

    assert {:ok, ^pl_a} = ETS.get("user-a")
    assert {:ok, ^pl_b} = ETS.get("user-b")
  end
end
