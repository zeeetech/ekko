defmodule Ekko.Test.CertFixtures do
  @moduledoc """
  Generates an in-memory RSA certificate chain with `echo-api.amazon.com`
  as a leaf SAN, for use by signature verifier and verifier pipeline tests.

  Generated lazily on first call and memoized in `:persistent_term` so the
  RSA keygen only happens once per test run.
  """

  @echo_api_host ~c"echo-api.amazon.com"
  @key :ekko_test_cert_fixtures

  @type fixture :: %{
          leaf_der: binary(),
          chain: [binary()],
          ca_der: binary(),
          pem: binary()
        }

  @spec fixture() :: fixture()
  def fixture do
    case :persistent_term.get(@key, :undefined) do
      :undefined ->
        f = generate()
        :persistent_term.put(@key, f)
        f

      f ->
        f
    end
  end

  @doc """
  Signs `body` with the fixture leaf private key and returns the Base64
  signature Amazon's `Signature-256` header would carry.
  """
  @spec sign(binary()) :: String.t()
  def sign(body) when is_binary(body) do
    %{private_key: {:RSAPrivateKey, _v, n, e, d, _p, _q, _dp, _dq, _qi, _other}} = fixture()
    :rsa |> :crypto.sign(:sha256, body, [e, n, d]) |> Base.encode64()
  end

  defp generate do
    chain_opts = %{
      server_chain: %{
        root: [{:key, {:rsa, 2048, 65_537}}],
        intermediates: [],
        peer: [
          {:key, {:rsa, 2048, 65_537}},
          {:extensions,
           [
             {:Extension, {2, 5, 29, 17}, false, [{:dNSName, @echo_api_host}]}
           ]}
        ]
      },
      client_chain: %{
        root: [{:key, {:rsa, 2048, 65_537}}],
        intermediates: [],
        peer: [{:key, {:rsa, 2048, 65_537}}]
      }
    }

    %{server_config: server_config} = :public_key.pkix_test_data(chain_opts)

    leaf_der = Keyword.fetch!(server_config, :cert)
    private_key = decode_private_key(Keyword.fetch!(server_config, :key))
    cacerts = Keyword.fetch!(server_config, :cacerts)

    chain = [leaf_der | cacerts]
    ca_der = List.last(cacerts)

    pem =
      :public_key.pem_encode(for der <- chain, do: {:Certificate, der, :not_encrypted})

    %{
      leaf_der: leaf_der,
      chain: chain,
      ca_der: ca_der,
      private_key: private_key,
      pem: pem
    }
  end

  defp decode_private_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_private_key(other), do: other
end
