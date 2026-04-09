defmodule Ekko.Crypto.CertDownloader do
  @moduledoc """
  Thin Finch wrapper used by `Ekko.Crypto.CertCache` to fetch the PEM body
  of an Alexa signing certificate chain over HTTPS.
  """

  @spec download(String.t()) :: {:ok, binary()} | {:error, term()}
  def download(url) when is_binary(url) do
    :get
    |> Finch.build(url)
    |> Finch.request(Ekko.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Finch.Response{status: status}} -> {:error, {:cert_download_status, status}}
      {:error, reason} -> {:error, {:cert_download_failed, reason}}
    end
  end
end
