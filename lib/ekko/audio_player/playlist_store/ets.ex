defmodule Ekko.AudioPlayer.PlaylistStore.ETS do
  @moduledoc """
  Default in-memory playlist store backed by a public ETS table.

  Suitable for development and single-node deployments. For production
  multi-node setups, implement `Ekko.AudioPlayer.PlaylistStore` with
  a distributed backend.

  The ETS table is owned by a tiny `Agent` so it survives process
  restarts via the supervision tree.
  """

  @behaviour Ekko.AudioPlayer.PlaylistStore

  use Agent

  @table :ekko_audio_player_playlists

  @doc "Starts the Agent that owns the ETS playlist table."
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(
      fn ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        :ok
      end,
      name: __MODULE__
    )
  end

  @doc "Retrieves the playlist for the given user, or `nil` if not found."
  @impl true
  def get(user_id) when is_binary(user_id) do
    case :ets.lookup(@table, user_id) do
      [{^user_id, playlist}] -> {:ok, playlist}
      [] -> {:ok, nil}
    end
  end

  @doc "Stores the playlist for the given user."
  @impl true
  def put(user_id, %Ekko.AudioPlayer.Playlist{} = playlist) when is_binary(user_id) do
    :ets.insert(@table, {user_id, playlist})
    :ok
  end

  @doc "Removes the playlist for the given user."
  @impl true
  def delete(user_id) when is_binary(user_id) do
    :ets.delete(@table, user_id)
    :ok
  end
end
