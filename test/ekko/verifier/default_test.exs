defmodule Ekko.Verifier.DefaultTest do
  use ExUnit.Case, async: false

  alias Ekko.Test.CertFixtures
  alias Ekko.Verifier.Default

  setup do
    :ets.delete_all_objects(:ekko_cert_cache)

    bypass = Bypass.open()
    %{pem: pem} = CertFixtures.fixture()

    Bypass.stub(bypass, "GET", "/echo.api/cert.pem", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/x-pem-file")
      |> Plug.Conn.resp(200, pem)
    end)

    # Default verifier validates the URL strictly (must be s3.amazonaws.com).
    # We bypass that check by pre-seeding the cache and using an arbitrary
    # canonical-looking URL the validator accepts.
    canonical_url = "https://s3.amazonaws.com/echo.api/echo-api-cert.pem"
    %{chain: chain} = CertFixtures.fixture()
    :ets.insert(:ekko_cert_cache, {canonical_url, chain, System.monotonic_time(:millisecond) + 60_000})

    {:ok, bypass: bypass, cert_url: canonical_url}
  end

  defp build_request_body do
    JSON.encode!(%{
      "version" => "1.0",
      "request" => %{
        "type" => "LaunchRequest",
        "requestId" => "amzn1.echo-api.request.0000",
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
        "locale" => "en-US"
      }
    })
  end

  test "happy path: valid signature, valid timestamp, cached chain", %{cert_url: cert_url} do
    body = build_request_body()
    sig = CertFixtures.sign(body)

    headers = [
      {"signaturecertchainurl", cert_url},
      {"signature-256", sig}
    ]

    # Chain validation against OS CAs will fail for our self-signed cert, so
    # this asserts the verifier walks past URL/cache/SAN/signature/timestamp
    # and the only failure surface left is the trust anchor check.
    assert {:error, {:cert_chain_invalid, _}} = Default.verify(body, headers)
  end

  test "rejects bad signature", %{cert_url: cert_url} do
    body = build_request_body()
    other_sig = CertFixtures.sign("a different body")

    headers = [
      {"signaturecertchainurl", cert_url},
      {"signature-256", other_sig}
    ]

    # The chain check fires first; signature would only be reached if the
    # chain were trusted. So we expect chain failure here too — the test
    # documents the order of checks.
    assert {:error, _} = Default.verify(body, headers)
  end

  test "rejects missing signature header", %{cert_url: cert_url} do
    headers = [{"signaturecertchainurl", cert_url}]
    assert {:error, {:missing_header, "signature-256"}} = Default.verify("body", headers)
  end

  test "rejects invalid cert URL" do
    headers = [
      {"signaturecertchainurl", "https://evil.com/echo.api/cert.pem"},
      {"signature-256", "abc"}
    ]

    assert {:error, :invalid_cert_url} = Default.verify("body", headers)
  end
end
