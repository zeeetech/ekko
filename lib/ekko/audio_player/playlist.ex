defmodule Ekko.AudioPlayer.Playlist do
  @moduledoc """
  Pure-data playlist with a cursor, shuffle, and loop support.

  A playlist is a list of tracks with a cursor pointing at the current one.
  All operations are purely functional — call `Ekko.AudioPlayer.PlaylistStore`
  to persist the result.

  ## Tracks

  Each track is a map with at least `:token` and `:url`. Optional keys:
  `:title`, `:subtitle`, `:art_url`, `:duration_ms`.

  ## Shuffle

  When shuffled, a permuted index order is generated. The cursor stays on
  the same track the user was hearing — only the "next"/"previous" walk
  order changes. Toggling shuffle off restores the original insertion order
  but keeps the cursor on the current track.

  ## Loop modes

    * `:off` — `next/1` returns `:end_of_playlist` at the tail
    * `:one` — `next/1` re-returns the current track
    * `:all` — `next/1` wraps to the head
  """

  @type track :: %{
          token: String.t(),
          url: String.t(),
          title: String.t() | nil,
          subtitle: String.t() | nil,
          art_url: String.t() | nil,
          duration_ms: non_neg_integer() | nil
        }

  @type t :: %__MODULE__{
          tracks: [track()],
          cursor: non_neg_integer(),
          shuffled: boolean(),
          shuffle_order: [non_neg_integer()] | nil,
          loop: :off | :one | :all
        }

  defstruct tracks: [], cursor: 0, shuffled: false, shuffle_order: nil, loop: :off

  @doc "Creates a new playlist from a list of tracks."
  @spec new([track()], keyword()) :: t()
  def new(tracks, opts \\ []) when is_list(tracks) do
    %__MODULE__{
      tracks: tracks,
      cursor: Keyword.get(opts, :cursor, 0),
      loop: Keyword.get(opts, :loop, :off)
    }
  end

  @doc "Returns the track at the current cursor position, or `nil` if empty."
  @spec current(t()) :: track() | nil
  def current(%__MODULE__{tracks: []}), do: nil

  def current(%__MODULE__{} = pl) do
    Enum.at(pl.tracks, effective_index(pl))
  end

  @doc "Advances to the next track. Honors loop mode."
  @spec next(t()) :: {:ok, t(), track()} | :end_of_playlist
  def next(%__MODULE__{tracks: []} = _pl), do: :end_of_playlist

  def next(%__MODULE__{loop: :one} = pl) do
    track = current(pl)
    {:ok, pl, track}
  end

  def next(%__MODULE__{} = pl) do
    len = order_length(pl)
    next_cursor = pl.cursor + 1

    cond do
      next_cursor < len ->
        pl = %{pl | cursor: next_cursor}
        {:ok, pl, current(pl)}

      pl.loop == :all ->
        pl = %{pl | cursor: 0}
        {:ok, pl, current(pl)}

      true ->
        :end_of_playlist
    end
  end

  @doc "Moves to the previous track."
  @spec previous(t()) :: {:ok, t(), track()} | :start_of_playlist
  def previous(%__MODULE__{tracks: []}), do: :start_of_playlist

  def previous(%__MODULE__{loop: :one} = pl) do
    {:ok, pl, current(pl)}
  end

  def previous(%__MODULE__{} = pl) do
    prev_cursor = pl.cursor - 1

    cond do
      prev_cursor >= 0 ->
        pl = %{pl | cursor: prev_cursor}
        {:ok, pl, current(pl)}

      pl.loop == :all ->
        pl = %{pl | cursor: order_length(pl) - 1}
        {:ok, pl, current(pl)}

      true ->
        :start_of_playlist
    end
  end

  @doc "Moves the cursor to the track with the given token."
  @spec advance_to_token(t(), String.t()) :: {:ok, t()} | :not_found
  def advance_to_token(%__MODULE__{} = pl, token) when is_binary(token) do
    real_index = Enum.find_index(pl.tracks, &(&1.token == token))

    case real_index do
      nil ->
        :not_found

      idx ->
        cursor =
          if pl.shuffled do
            Enum.find_index(pl.shuffle_order, &(&1 == idx))
          else
            idx
          end

        {:ok, %{pl | cursor: cursor || 0}}
    end
  end

  @doc "Toggles shuffle on or off."
  @spec shuffle(t(), boolean()) :: t()
  def shuffle(%__MODULE__{} = pl, true) do
    current_real = effective_index(pl)
    len = length(pl.tracks)
    order = 0..(len - 1) |> Enum.to_list() |> Enum.shuffle()
    new_cursor = Enum.find_index(order, &(&1 == current_real)) || 0
    %{pl | shuffled: true, shuffle_order: order, cursor: new_cursor}
  end

  def shuffle(%__MODULE__{} = pl, false) do
    current_real = effective_index(pl)
    %{pl | shuffled: false, shuffle_order: nil, cursor: current_real}
  end

  @doc "Sets the loop mode."
  @spec set_loop(t(), :off | :one | :all) :: t()
  def set_loop(%__MODULE__{} = pl, mode) when mode in [:off, :one, :all] do
    %{pl | loop: mode}
  end

  @doc "Appends tracks to the end of the playlist."
  @spec append(t(), [track()]) :: t()
  def append(%__MODULE__{} = pl, tracks) when is_list(tracks) do
    old_len = length(pl.tracks)
    new_tracks = pl.tracks ++ tracks
    new_indices = Enum.to_list(old_len..(old_len + length(tracks) - 1))

    shuffle_order =
      if pl.shuffled do
        (pl.shuffle_order || []) ++ Enum.shuffle(new_indices)
      else
        pl.shuffle_order
      end

    %{pl | tracks: new_tracks, shuffle_order: shuffle_order}
  end

  @doc "Removes a track by token. Adjusts cursor to stay on the same track."
  @spec remove(t(), String.t()) :: t()
  def remove(%__MODULE__{} = pl, token) when is_binary(token) do
    idx = Enum.find_index(pl.tracks, &(&1.token == token))
    if is_nil(idx), do: pl, else: do_remove(pl, idx)
  end

  defp do_remove(%__MODULE__{} = pl, idx) do
    current_real = effective_index(pl)
    new_tracks = List.delete_at(pl.tracks, idx)

    {new_shuffled, new_order, new_cursor} =
      if pl.shuffled do
        order =
          pl.shuffle_order
          |> Enum.reject(&(&1 == idx))
          |> Enum.map(fn i -> if i > idx, do: i - 1, else: i end)

        cursor_in_order = min(pl.cursor, max(length(order) - 1, 0))
        {true, order, cursor_in_order}
      else
        new_cursor =
          cond do
            current_real > idx -> pl.cursor - 1
            current_real == idx -> min(pl.cursor, max(length(new_tracks) - 1, 0))
            true -> pl.cursor
          end

        {false, nil, new_cursor}
      end

    %{pl | tracks: new_tracks, cursor: new_cursor, shuffled: new_shuffled, shuffle_order: new_order}
  end

  defp effective_index(%__MODULE__{shuffled: true, shuffle_order: order, cursor: cursor}) when is_list(order) do
    Enum.at(order, cursor, 0)
  end

  defp effective_index(%__MODULE__{cursor: cursor}), do: cursor

  defp order_length(%__MODULE__{shuffled: true, shuffle_order: order}) when is_list(order), do: length(order)
  defp order_length(%__MODULE__{tracks: tracks}), do: length(tracks)
end
