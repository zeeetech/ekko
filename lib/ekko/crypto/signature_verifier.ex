defmodule Ekko.Crypto.SignatureVerifier do
  @moduledoc """
  Verifies the RSA-SHA256 signature Amazon attaches to every Alexa request
  via the `Signature-256` HTTP header.
  """

  require Record

  Record.defrecordp(
    :otp_certificate,
    :OTPCertificate,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecordp(
    :otp_tbs_certificate,
    :OTPTBSCertificate,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecordp(
    :otp_subject_public_key_info,
    :OTPSubjectPublicKeyInfo,
    Record.extract(:OTPSubjectPublicKeyInfo, from_lib: "public_key/include/public_key.hrl")
  )

  @doc """
  Verifies `signature_b64` (a Base64-encoded RSA-SHA256 signature) against
  `raw_body` using the public key extracted from the leaf certificate (DER).
  """
  @spec verify(binary(), String.t(), binary()) :: :ok | {:error, term()}
  def verify(raw_body, signature_b64, leaf_der)
      when is_binary(raw_body) and is_binary(signature_b64) and is_binary(leaf_der) do
    with {:ok, signature} <- decode_signature(signature_b64),
         {:ok, public_key} <- extract_public_key(leaf_der) do
      if :public_key.verify(raw_body, :sha256, signature, public_key) do
        :ok
      else
        {:error, :signature_invalid}
      end
    end
  rescue
    _ -> {:error, :signature_invalid}
  end

  defp decode_signature(b64) do
    case Base.decode64(b64) do
      {:ok, sig} -> {:ok, sig}
      :error -> {:error, :signature_invalid}
    end
  end

  defp extract_public_key(der) do
    otp_certificate(tbsCertificate: tbs) = :public_key.pkix_decode_cert(der, :otp)
    otp_tbs_certificate(subjectPublicKeyInfo: spki) = tbs
    otp_subject_public_key_info(subjectPublicKey: public_key) = spki
    {:ok, public_key}
  rescue
    _ -> {:error, :invalid_leaf_cert}
  end
end
