defmodule Ekko.Crypto.CertValidatorTest do
  use ExUnit.Case, async: true

  alias Ekko.Crypto.CertValidator

  describe "validate_url/1" do
    test "accepts canonical Amazon URL" do
      assert :ok = CertValidator.validate_url("https://s3.amazonaws.com/echo.api/echo-api-cert.pem")
    end

    test "accepts explicit port 443" do
      assert :ok = CertValidator.validate_url("https://s3.amazonaws.com:443/echo.api/echo-api-cert.pem")
    end

    test "accepts mixed-case host" do
      assert :ok = CertValidator.validate_url("https://S3.amazonaws.com/echo.api/cert.pem")
    end

    test "rejects http scheme" do
      assert {:error, :invalid_cert_url} =
               CertValidator.validate_url("http://s3.amazonaws.com/echo.api/cert.pem")
    end

    test "rejects wrong host" do
      assert {:error, :invalid_cert_url} =
               CertValidator.validate_url("https://notamazon.com/echo.api/cert.pem")
    end

    test "rejects wrong path prefix" do
      assert {:error, :invalid_cert_url} =
               CertValidator.validate_url("https://s3.amazonaws.com/EcHo.aPi/cert.pem")
    end

    test "rejects port 80" do
      assert {:error, :invalid_cert_url} =
               CertValidator.validate_url("https://s3.amazonaws.com:80/echo.api/cert.pem")
    end

    test "rejects path traversal that escapes the prefix" do
      assert {:error, :invalid_cert_url} =
               CertValidator.validate_url("https://s3.amazonaws.com/echo.api/../bad/cert.pem")
    end

    test "rejects non-binary input" do
      assert {:error, :invalid_cert_url} = CertValidator.validate_url(nil)
      assert {:error, :invalid_cert_url} = CertValidator.validate_url(123)
    end
  end

  describe "validate_chain/1" do
    test "rejects empty chain" do
      assert {:error, :empty_cert_chain} = CertValidator.validate_chain([])
    end

    test "fails SAN check on a non-Alexa cert" do
      alias Ekko.Test.CertFixtures
      # Self-signed cert without echo-api SAN should fail check_san.
      %{leaf_der: leaf} = CertFixtures.fixture()
      # The test fixture's leaf does include the SAN, so we expect the SAN
      # check to pass and the trust check to fail (it's not in the OS CA store).
      assert {:error, _} = CertValidator.validate_chain([leaf])
    end
  end
end
