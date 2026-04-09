defmodule Ekko.Internal.MapUtils do
  @moduledoc false

  @doc """
  Inserts `key => value` into `map` unless `value` is `nil`.
  """
  @spec maybe_put(map(), String.t(), term()) :: map()
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  Inserts `key => list` into `map` unless `list` is `nil` or `[]`.
  """
  @spec maybe_put_list(map(), String.t(), list() | nil) :: map()
  def maybe_put_list(map, _key, nil), do: map
  def maybe_put_list(map, _key, []), do: map
  def maybe_put_list(map, key, list) when is_list(list), do: Map.put(map, key, list)
end
