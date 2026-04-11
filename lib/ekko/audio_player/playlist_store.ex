defmodule Ekko.AudioPlayer.PlaylistStore do
  @moduledoc """
  Behaviour for persisting `Ekko.AudioPlayer.Playlist` state per Alexa user.

  The key is the Alexa `userId` (from `session.user.userId` or
  `context.System.user.userId`), which is stable per skill installation.

  Ekko ships a default in-memory ETS adapter
  (`Ekko.AudioPlayer.PlaylistStore.ETS`). Implement this behaviour to
  back playlists with Redis, Postgres, session attributes, or any other
  store.

  Configure the active store in your config:

      config :ekko, playlist_store: MyApp.RedisPlaylistStore
  """

  alias Ekko.AudioPlayer.Playlist

  @callback get(user_id :: String.t()) :: {:ok, Playlist.t() | nil} | {:error, term()}
  @callback put(user_id :: String.t(), Playlist.t()) :: :ok | {:error, term()}
  @callback delete(user_id :: String.t()) :: :ok | {:error, term()}
end
