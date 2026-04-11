defmodule Ekko.AudioPlayer do
  @moduledoc """
  High-level helpers for building AudioPlayer responses from a
  `Ekko.AudioPlayer.Playlist`.

  These wrap the low-level directive builders in `Ekko` and translate
  `Playlist.track()` maps into the args those builders expect.

  ## Store operations

  `load/1`, `save/2`, and `clear/1` delegate to the configured
  `Ekko.AudioPlayer.PlaylistStore` implementation:

      config :ekko, playlist_store: Ekko.AudioPlayer.PlaylistStore.ETS

  ## Directive helpers

  `play_current/2`, `play_next/2`, `play_previous/2`, `enqueue_next/2`,
  `stop_playback/1`, and `clear_and_play/2` pipe directives onto an
  `%Ekko{}` context, ready to be passed to `Ekko.build/1`.
  """

  alias Ekko.AudioPlayer.Playlist

  # ── Store operations ─────────────────────────────────────────────────────

  @doc "Loads the playlist for `user_id` from the configured store."
  @spec load(String.t()) :: {:ok, Playlist.t() | nil} | {:error, term()}
  def load(user_id) when is_binary(user_id), do: store().get(user_id)

  @doc "Saves the playlist for `user_id` to the configured store."
  @spec save(String.t(), Playlist.t()) :: :ok | {:error, term()}
  def save(user_id, %Playlist{} = playlist), do: store().put(user_id, playlist)

  @doc "Deletes the playlist for `user_id` from the configured store."
  @spec clear(String.t()) :: :ok | {:error, term()}
  def clear(user_id) when is_binary(user_id), do: store().delete(user_id)

  # ── Directive helpers ──────────────────────────────────────────────────

  @doc """
  Emits an `AudioPlayer.Play` directive for the current track in the
  playlist with `:replace_all` behavior.
  """
  @spec play_current(Ekko.t(), Playlist.t()) :: Ekko.t()
  def play_current(%Ekko{} = ekko, %Playlist{} = pl) do
    case Playlist.current(pl) do
      nil -> ekko
      track -> play_track(ekko, :replace_all, track, [])
    end
  end

  @doc """
  Advances the playlist and emits `AudioPlayer.Play` with `:replace_all`.

  Returns `{ekko, updated_playlist}` on success, or `:end_of_playlist`.
  """
  @spec play_next(Ekko.t(), Playlist.t()) :: {Ekko.t(), Playlist.t()} | :end_of_playlist
  def play_next(%Ekko{} = ekko, %Playlist{} = pl) do
    case Playlist.next(pl) do
      {:ok, pl, track} -> {play_track(ekko, :replace_all, track, []), pl}
      :end_of_playlist -> :end_of_playlist
    end
  end

  @doc """
  Moves the playlist backward and emits `AudioPlayer.Play` with `:replace_all`.

  Returns `{ekko, updated_playlist}` on success, or `:start_of_playlist`.
  """
  @spec play_previous(Ekko.t(), Playlist.t()) :: {Ekko.t(), Playlist.t()} | :start_of_playlist
  def play_previous(%Ekko{} = ekko, %Playlist{} = pl) do
    case Playlist.previous(pl) do
      {:ok, pl, track} -> {play_track(ekko, :replace_all, track, []), pl}
      :start_of_playlist -> :start_of_playlist
    end
  end

  @doc """
  Peeks at the next track and emits `AudioPlayer.Play` with `:enqueue`,
  setting `expected_previous_token` to the current track's token.

  This is the typical call inside a `PlaybackNearlyFinished` handler.
  Returns the updated `%Ekko{}`, or the unchanged `ekko` if there's no
  next track.
  """
  @spec enqueue_next(Ekko.t(), Playlist.t()) :: Ekko.t()
  def enqueue_next(%Ekko{} = ekko, %Playlist{} = pl) do
    current = Playlist.current(pl)

    case Playlist.next(pl) do
      {:ok, _pl, next_track} ->
        prev_token = if current, do: current.token
        play_track(ekko, :enqueue, next_track, expected_previous_token: prev_token)

      :end_of_playlist ->
        ekko
    end
  end

  @doc "Emits an `AudioPlayer.Stop` directive."
  @spec stop_playback(Ekko.t()) :: Ekko.t()
  def stop_playback(%Ekko{} = ekko), do: Ekko.add_audio_player_stop(ekko)

  @doc """
  Clears the queue and immediately plays the current track.
  Equivalent to `AudioPlayer.ClearQueue` with `:clear_all` followed by
  `AudioPlayer.Play` with `:replace_all`.
  """
  @spec clear_and_play(Ekko.t(), Playlist.t()) :: Ekko.t()
  def clear_and_play(%Ekko{} = ekko, %Playlist{} = pl) do
    ekko
    |> Ekko.add_audio_player_clear_queue(:clear_all)
    |> play_current(pl)
  end

  # ── Private ────────────────────────────────────────────────────────────

  defp play_track(ekko, behavior, track, opts) do
    metadata =
      case {Map.get(track, :title), Map.get(track, :subtitle), Map.get(track, :art_url)} do
        {nil, nil, nil} -> []
        _ -> [metadata: %{title: track[:title], subtitle: track[:subtitle], art: track[:art_url]}]
      end

    Ekko.add_audio_player_play(
      ekko,
      behavior,
      track.url,
      track.token,
      0,
      opts ++ metadata
    )
  end

  defp store do
    Application.get_env(:ekko, :playlist_store, Ekko.AudioPlayer.PlaylistStore.ETS)
  end
end
