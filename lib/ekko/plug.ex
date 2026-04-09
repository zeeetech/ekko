defmodule Ekko.Plug do
  @moduledoc """
  Mountable Plug that turns an inbound HTTP request from the Alexa service
  into a call to `Ekko.handle/2`.

  Reads the raw body, hands it (with the request headers) to a verifier,
  dispatches the decoded request through the user's skill module, and
  writes the response JSON back. Verification is on by default and can be
  switched off for tests via `config :ekko, verify_requests: false`.

  ## Mounting

      plug Ekko.Plug, skill: MyApp.MusicSkill

  ## Options

    * `:skill` (required) — the skill module implementing `Ekko.Skill`.
    * `:verifier` — override the verifier module. Defaults to
      `Ekko.Verifier.Default` (or `Ekko.Verifier.NoOp` when
      `config :ekko, verify_requests: false`).

  ## Error mapping

  | Reason                              | Status |
  | ----------------------------------- | -----: |
  | `:invalid_cert_url`                 |    400 |
  | `{:cert_chain_invalid, _}`          |    400 |
  | `:san_mismatch`                     |    400 |
  | `:signature_invalid`                |    400 |
  | `:timestamp_too_old`                |    400 |
  | `:timestamp_in_future`              |    400 |
  | `:invalid_timestamp`                |    400 |
  | `{:invalid_json, _}`                |    400 |
  | `:invalid_json_shape`               |    400 |
  | `{:missing_header, _}`              |    400 |
  | `:invalid_request` and the like    |    400 |
  | `{:cert_download_failed, _}`        |    503 |
  | `{:cert_download_status, _}`        |    503 |
  | anything else                       |    500 |
  """

  @behaviour Plug

  require Logger

  @impl true
  def init(opts) do
    skill = Keyword.fetch!(opts, :skill)
    verifier = Keyword.get(opts, :verifier, default_verifier())
    %{skill: skill, verifier: verifier}
  end

  @impl true
  def call(conn, %{skill: skill, verifier: verifier}) do
    with {:ok, raw_body, conn} <- read_raw_body(conn),
         {:ok, decoded} <- verifier.verify(raw_body, conn.req_headers),
         {:ok, response} <- Ekko.handle(skill, decoded) do
      send_json(conn, 200, response)
    else
      {:error, reason} -> send_error(conn, reason)
    end
  end

  defp default_verifier do
    if Application.get_env(:ekko, :verify_requests, true) do
      Ekko.Verifier.Default
    else
      Ekko.Verifier.NoOp
    end
  end

  defp read_raw_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} -> {:ok, body, conn}
      {:more, _partial, _conn} -> {:error, :body_too_large}
      {:error, reason} -> {:error, {:body_read_failed, reason}}
    end
  end

  defp send_error(conn, reason) do
    status = status_for(reason)
    Logger.warning("ekko: rejecting request with status #{status}: #{inspect(reason)}")
    send_json(conn, status, %{"error" => to_string(error_code(reason))})
  end

  defp send_json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, JSON.encode!(body))
  end

  defp status_for(:invalid_cert_url), do: 400
  defp status_for(:san_mismatch), do: 400
  defp status_for({:cert_chain_invalid, _}), do: 400
  defp status_for(:signature_invalid), do: 400
  defp status_for(:timestamp_too_old), do: 400
  defp status_for(:timestamp_in_future), do: 400
  defp status_for(:invalid_timestamp), do: 400
  defp status_for(:invalid_leaf_cert), do: 400
  defp status_for(:invalid_json_shape), do: 400
  defp status_for({:invalid_json, _}), do: 400
  defp status_for({:missing_header, _}), do: 400
  defp status_for(:invalid_request), do: 400
  defp status_for(:empty_cert_chain), do: 400
  defp status_for({:cert_download_failed, _}), do: 503
  defp status_for({:cert_download_status, _}), do: 503
  defp status_for(:body_too_large), do: 413
  defp status_for(_), do: 500

  defp error_code(reason) when is_atom(reason), do: reason
  defp error_code({code, _}) when is_atom(code), do: code
  defp error_code(_), do: :internal_error
end
