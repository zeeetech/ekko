defmodule Ekko.Verifier.Default do
  @moduledoc """
  Production verifier implementing the full 5-step pipeline Amazon mandates
  for [hosting a custom skill as a web service](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html):

    1. validate the structure of `SignatureCertChainUrl`
    2. fetch the certificate chain (cached in ETS by URL)
    3. validate the chain against the OS-trusted CAs and assert the leaf SAN
    4. verify the RSA-SHA256 body signature with the leaf's public key
    5. validate the request timestamp falls inside the configured tolerance

  Steps 2 and 5 also need the decoded request — we decode the body once here
  and return the parsed map so `Ekko.Plug` doesn't double-decode.
  """

  @behaviour Ekko.Verifier

  alias Ekko.Crypto.CertCache
  alias Ekko.Crypto.CertValidator
  alias Ekko.Crypto.SignatureVerifier

  @default_tolerance_seconds 150

  @impl true
  def verify(raw_body, headers) when is_binary(raw_body) and is_list(headers) do
    with {:ok, cert_url} <- header(headers, "signaturecertchainurl"),
         {:ok, signature} <- header(headers, "signature-256"),
         :ok <- CertValidator.validate_url(cert_url),
         {:ok, chain} <- CertCache.fetch(cert_url),
         :ok <- CertValidator.validate_chain(chain),
         :ok <- verify_signature(raw_body, signature, chain),
         {:ok, decoded} <- decode_body(raw_body),
         :ok <- validate_timestamp(decoded) do
      {:ok, decoded}
    end
  end

  defp verify_signature(raw_body, signature, [leaf | _]) do
    SignatureVerifier.verify(raw_body, signature, leaf)
  end

  defp header(headers, name) do
    case Enum.find(headers, fn {k, _} -> String.downcase(k) == name end) do
      {_, value} -> {:ok, value}
      nil -> {:error, {:missing_header, name}}
    end
  end

  defp decode_body(raw_body) do
    case JSON.decode(raw_body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _other} -> {:error, :invalid_json_shape}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  defp validate_timestamp(%{"request" => %{"timestamp" => ts}}) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, request_dt, _} ->
        delta = DateTime.diff(DateTime.utc_now(), request_dt, :second)
        tolerance = Application.get_env(:ekko, :timestamp_tolerance_seconds, @default_tolerance_seconds)

        cond do
          delta > tolerance -> {:error, :timestamp_too_old}
          delta < -tolerance -> {:error, :timestamp_in_future}
          true -> :ok
        end

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  defp validate_timestamp(_), do: {:error, :invalid_timestamp}
end
