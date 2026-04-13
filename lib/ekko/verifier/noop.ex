defmodule Ekko.Verifier.NoOp do
  @moduledoc """
  Verifier implementation that skips signature checking and just decodes the
  JSON body. Selected automatically when `config :ekko, verify_requests:
  false` and intended for tests / local development.

  **Never use in production.** Amazon's web service hosting requirements
  mandate the full verification pipeline implemented in
  `Ekko.Verifier.Default`.
  """

  @behaviour Ekko.Verifier

  @doc "Accepts any request body without verification. Decodes the JSON and returns the map."
  @impl true
  def verify(raw_body, _headers) when is_binary(raw_body) do
    case JSON.decode(raw_body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _other} -> {:error, :invalid_json_shape}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end
end
