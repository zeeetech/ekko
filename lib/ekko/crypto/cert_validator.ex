defmodule Ekko.Crypto.CertValidator do
  @moduledoc """
  URL and X.509 chain validation for Alexa request signatures.

  Implements the rules from Amazon's
  [host a custom skill as a web service guide](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html):

    * the `SignatureCertChainUrl` value must be `https://s3.amazonaws.com/echo.api/...`
      with port 443 (or no port), and the path must start with `/echo.api/`
      after normalizing `..` segments;
    * the leaf certificate's Subject Alternative Name list must include
      `echo-api.amazon.com`;
    * the chain must validate against the OS-trusted CAs returned by
      `:public_key.cacerts_get/0`.
  """

  @echo_api_host "echo-api.amazon.com"
  @s3_host "s3.amazonaws.com"
  @path_prefix "/echo.api/"

  @doc """
  Validates the structure and origin of a `SignatureCertChainUrl` value.
  """
  @spec validate_url(String.t()) :: :ok | {:error, :invalid_cert_url}
  def validate_url(url) when is_binary(url) do
    with %URI{scheme: "https", host: host, path: path, port: port} when is_binary(host) <- URI.parse(url),
         true <- String.downcase(host) == @s3_host,
         true <- port in [nil, 443],
         normalized when is_binary(normalized) <- normalize_path(path),
         true <- String.starts_with?(normalized, @path_prefix) do
      :ok
    else
      _ -> {:error, :invalid_cert_url}
    end
  end

  def validate_url(_), do: {:error, :invalid_cert_url}

  @doc """
  Validates a parsed certificate chain against the OS-trusted CA store and
  asserts that the leaf certificate's SAN includes `echo-api.amazon.com`.

  `chain` is a list of DER-encoded certificates with the leaf first
  (the order Amazon delivers them).
  """
  @spec validate_chain([binary()]) :: :ok | {:error, term()}
  def validate_chain([leaf | _] = der_chain) when is_list(der_chain) do
    with :ok <- check_san(leaf) do
      check_trust(der_chain)
    end
  end

  def validate_chain(_), do: {:error, :empty_cert_chain}

  defp check_san(leaf_der) do
    otp_cert = :public_key.pkix_decode_cert(leaf_der, :otp)

    if :public_key.pkix_verify_hostname(otp_cert, [{:dns_id, String.to_charlist(@echo_api_host)}]) do
      :ok
    else
      {:error, :san_mismatch}
    end
  rescue
    _ -> {:error, :invalid_leaf_cert}
  end

  defp check_trust(amazon_chain) do
    # Amazon delivers the chain leaf-first; pkix_path_validation wants
    # the path ordered from the trust anchor's child down to the leaf.
    ordered = Enum.reverse(amazon_chain)
    [topmost | _] = ordered
    cacerts = :public_key.cacerts_get()

    case find_anchor(topmost, cacerts) do
      {:ok, anchor} ->
        case :public_key.pkix_path_validation(anchor, ordered, []) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, {:cert_chain_invalid, reason}}
        end

      :error ->
        {:error, {:cert_chain_invalid, :no_trust_anchor}}
    end
  rescue
    error -> {:error, {:cert_chain_invalid, error}}
  end

  defp find_anchor(child, cacerts) do
    Enum.find_value(cacerts, :error, fn anchor ->
      if :public_key.pkix_is_issuer(child, anchor), do: {:ok, anchor}
    end)
  end

  defp normalize_path(nil), do: nil

  defp normalize_path(path) when is_binary(path) do
    segments =
      path
      |> String.split("/", trim: false)
      |> Enum.reduce([], fn
        "..", [_ | rest] -> rest
        "..", [] -> []
        ".", acc -> acc
        seg, acc -> [seg | acc]
      end)
      |> Enum.reverse()

    "/" <> Enum.join(Enum.drop(segments, 1), "/")
  end
end
