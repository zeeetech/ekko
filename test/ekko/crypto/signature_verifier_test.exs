defmodule Ekko.Crypto.SignatureVerifierTest do
  use ExUnit.Case, async: true

  alias Ekko.Crypto.SignatureVerifier
  alias Ekko.Test.CertFixtures

  test "verifies a signature produced by the matching private key" do
    body = ~s({"version":"1.0","request":{"type":"LaunchRequest"}})
    signature = CertFixtures.sign(body)
    %{leaf_der: leaf} = CertFixtures.fixture()

    assert :ok = SignatureVerifier.verify(body, signature, leaf)
  end

  test "rejects a tampered body" do
    body = "original body"
    signature = CertFixtures.sign(body)
    %{leaf_der: leaf} = CertFixtures.fixture()

    assert {:error, :signature_invalid} =
             SignatureVerifier.verify("tampered body", signature, leaf)
  end

  test "rejects a malformed Base64 signature" do
    %{leaf_der: leaf} = CertFixtures.fixture()
    assert {:error, :signature_invalid} = SignatureVerifier.verify("body", "!!!not base64!!!", leaf)
  end

  test "rejects an invalid leaf cert" do
    body = "body"
    signature = CertFixtures.sign(body)
    assert {:error, _} = SignatureVerifier.verify(body, signature, <<0, 1, 2, 3>>)
  end
end
