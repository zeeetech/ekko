defmodule Ekko.Crypto.CertCache do
  @moduledoc """
  TTL cache for parsed Alexa signing certificate chains.

  Keyed by `SignatureCertChainUrl`. The cache itself is a public ETS table
  owned by a tiny `Agent` so the table survives nothing-but-process restarts
  via the supervision tree. Reads and writes happen directly on the table —
  the Agent state is unused; the process exists only as the table owner.

  Entries are `{url, parsed_chain, expires_at_monotonic_ms}` where
  `parsed_chain` is the list of DER-encoded certificates returned by
  `Ekko.Crypto.CertDownloader.download/1` and parsed via
  `:public_key.pem_decode/1`.
  """

  use Agent

  alias Ekko.Crypto.CertDownloader

  @table :ekko_cert_cache

  @doc "Starts the Agent that owns the ETS certificate cache table."
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(
      fn ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        :ok
      end,
      name: __MODULE__
    )
  end

  @doc """
  Returns the parsed DER chain for `url`, downloading and caching it on miss
  or after expiry.
  """
  @spec fetch(String.t()) :: {:ok, [binary()]} | {:error, term()}
  def fetch(url) when is_binary(url) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, url) do
      [{^url, chain, expires_at}] when expires_at > now ->
        {:ok, chain}

      _ ->
        download_and_store(url, now)
    end
  end

  defp download_and_store(url, now) do
    with {:ok, body} <- CertDownloader.download(url),
         {:ok, chain} <- parse_pem(body) do
      :ets.insert(@table, {url, chain, now + ttl_ms()})
      {:ok, chain}
    end
  end

  defp parse_pem(pem) do
    case :public_key.pem_decode(pem) do
      [] ->
        {:error, :empty_cert_chain}

      entries ->
        chain =
          for {:Certificate, der, _} <- entries do
            der
          end

        if chain == [], do: {:error, :empty_cert_chain}, else: {:ok, chain}
    end
  rescue
    error -> {:error, {:cert_parse_failed, error}}
  end

  defp ttl_ms do
    Application.get_env(:ekko, :cert_cache_ttl_ms, 86_400_000)
  end
end
