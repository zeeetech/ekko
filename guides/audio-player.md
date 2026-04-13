# AudioPlayer Integration

This guide covers building streaming audio skills with Ekko's AudioPlayer
support.

## AudioPlayer request types

When your skill plays audio, Alexa sends lifecycle notifications as the
stream progresses. These arrive as `%Ekko.Request.AudioPlayer{}` structs
with an `:event` field:

| Event | When |
|-------|------|
| `:started` | Playback began |
| `:nearly_finished` | Stream is about to end — enqueue the next track here |
| `:finished` | Stream completed naturally |
| `:stopped` | User or directive stopped playback |
| `:failed` | Playback error (check `:error` field) |

Additionally, when the user presses hardware buttons or says "Alexa, next",
you receive `%Ekko.Request.PlaybackController{}` with a `:command` field:

| Command | Trigger |
|---------|---------|
| `:play` | "Alexa, play" |
| `:pause` | "Alexa, pause" |
| `:next` | "Alexa, next" |
| `:previous` | "Alexa, previous" |
| `:resume` | "Alexa, resume" |

## Response constraints

AudioPlayer and PlaybackController requests are notification-style. Amazon
forbids `outputSpeech`, `card`, and `reprompt` in the response. Ekko
enforces this at the framework level — if your handler returns any of these
fields, `Ekko.handle/2` returns
`{:error, {:invalid_audio_player_response, field}}` and routes through
`handle_error/3`.

Your handlers should return only directives:

```elixir
def handle_request(%AudioPlayer{event: :nearly_finished}, ekko) do
  response =
    ekko
    |> Ekko.add_audio_player_play(:enqueue, next_url, next_token, 0,
         expected_previous_token: current_token)
    |> Ekko.build()

  {:ok, response}
end
```

## Playlist management

For skills that need next/previous/shuffle, Ekko provides
`Ekko.AudioPlayer.Playlist` — a pure-data struct with a cursor:

```elixir
alias Ekko.AudioPlayer.Playlist

tracks = [
  %{token: "t1", url: "https://example.com/1.mp3", title: "Song 1",
    subtitle: nil, art_url: nil, duration_ms: 180_000},
  %{token: "t2", url: "https://example.com/2.mp3", title: "Song 2",
    subtitle: nil, art_url: nil, duration_ms: 210_000},
  %{token: "t3", url: "https://example.com/3.mp3", title: "Song 3",
    subtitle: nil, art_url: nil, duration_ms: 195_000}
]

playlist = Playlist.new(tracks, loop: :all)
```

### Navigation

```elixir
# Advance
{:ok, playlist, track} = Playlist.next(playlist)

# Go back
{:ok, playlist, track} = Playlist.previous(playlist)

# Jump to a specific track by token
{:ok, playlist} = Playlist.advance_to_token(playlist, "t2")

# Current track
track = Playlist.current(playlist)
```

### Shuffle and loop

```elixir
# Toggle shuffle (preserves the currently-playing track)
playlist = Playlist.shuffle(playlist, true)
playlist = Playlist.shuffle(playlist, false)

# Loop modes: :off, :one, :all
playlist = Playlist.set_loop(playlist, :all)
```

### Modify the playlist

```elixir
playlist = Playlist.append(playlist, [new_track])
playlist = Playlist.remove(playlist, "t2")
```

## High-level helpers

`Ekko.AudioPlayer` wraps the low-level directive builders and translates
playlist tracks into the right arguments:

```elixir
alias Ekko.AudioPlayer

# Play the current track (replace_all)
ekko = AudioPlayer.play_current(ekko, playlist)

# Advance and play
{ekko, playlist} = AudioPlayer.play_next(ekko, playlist)

# Go back and play
{ekko, playlist} = AudioPlayer.play_previous(ekko, playlist)

# Enqueue the next track (for :nearly_finished handlers)
ekko = AudioPlayer.enqueue_next(ekko, playlist)

# Stop
ekko = AudioPlayer.stop_playback(ekko)

# Clear queue and play from the top
ekko = AudioPlayer.clear_and_play(ekko, playlist)
```

## Persisting playlists

Playlists are plain structs. To persist them across requests, use
`Ekko.AudioPlayer.PlaylistStore`:

```elixir
# Save
AudioPlayer.save(user_id, playlist)

# Load
{:ok, playlist} = AudioPlayer.load(user_id)

# Clear
AudioPlayer.clear(user_id)
```

The default store is `Ekko.AudioPlayer.PlaylistStore.ETS` (in-memory,
single-node). For production, implement the behaviour with your own backend:

```elixir
defmodule MyApp.RedisPlaylistStore do
  @behaviour Ekko.AudioPlayer.PlaylistStore

  @impl true
  def get(user_id) do
    case MyApp.Redis.get("playlist:#{user_id}") do
      nil -> {:ok, nil}
      data -> {:ok, :erlang.binary_to_term(data)}
    end
  end

  @impl true
  def put(user_id, playlist) do
    MyApp.Redis.set("playlist:#{user_id}", :erlang.term_to_binary(playlist))
    :ok
  end

  @impl true
  def delete(user_id) do
    MyApp.Redis.del("playlist:#{user_id}")
    :ok
  end
end
```

Configure it:

```elixir
config :ekko, playlist_store: MyApp.RedisPlaylistStore
```

## Putting it all together

```elixir
defmodule MyApp.MusicSkill do
  use Ekko.Skill

  alias Ekko.AudioPlayer
  alias Ekko.AudioPlayer.Playlist
  alias Ekko.Request

  @impl Ekko.Skill
  def handle_request(%Request.Launch{}, ekko) do
    playlist = Playlist.new(my_tracks(), loop: :all)
    AudioPlayer.save(user_id(ekko), playlist)

    response =
      ekko
      |> AudioPlayer.play_current(playlist)
      |> Ekko.build()

    {:ok, response}
  end

  def handle_request(%Request.AudioPlayer{event: :nearly_finished}, ekko) do
    {:ok, playlist} = AudioPlayer.load(user_id(ekko))

    response =
      ekko
      |> AudioPlayer.enqueue_next(playlist)
      |> Ekko.build()

    {:ok, response}
  end

  def handle_request(%Request.PlaybackController{command: :next}, ekko) do
    {:ok, playlist} = AudioPlayer.load(user_id(ekko))

    case AudioPlayer.play_next(ekko, playlist) do
      {ekko, playlist} ->
        AudioPlayer.save(user_id(ekko), playlist)
        {:ok, Ekko.build(ekko)}

      :end_of_playlist ->
        {:ok, Ekko.build(ekko)}
    end
  end

  def handle_request(%Request.PlaybackController{command: :pause}, ekko) do
    {:ok, ekko |> AudioPlayer.stop_playback() |> Ekko.build()}
  end

  defp user_id(ekko), do: ekko.request.context.system.user_id
  defp my_tracks, do: [...]
end
```
