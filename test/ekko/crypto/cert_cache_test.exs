defmodule Ekko.Crypto.CertCacheTest do
  use ExUnit.Case, async: false

  alias Ekko.Crypto.CertCache
  alias Ekko.Test.CertFixtures

  setup do
    # Clear the cache between tests so each starts cold.
    :ets.delete_all_objects(:ekko_cert_cache)
    :ok
  end

  test "fetch hits Bypass on first call and caches the result" do
    bypass = Bypass.open()
    %{pem: pem} = CertFixtures.fixture()
    url = "http://localhost:#{bypass.port}/echo.api/cert.pem"

    counter = :counters.new(1, [])

    Bypass.expect(bypass, "GET", "/echo.api/cert.pem", fn conn ->
      :counters.add(counter, 1, 1)

      conn
      |> Plug.Conn.put_resp_content_type("application/x-pem-file")
      |> Plug.Conn.resp(200, pem)
    end)

    assert {:ok, [_leaf | _]} = CertCache.fetch(url)
    assert {:ok, [_leaf | _]} = CertCache.fetch(url)

    assert :counters.get(counter, 1) == 1
  end

  test "expired entries trigger a re-download" do
    bypass = Bypass.open()
    %{pem: pem} = CertFixtures.fixture()
    url = "http://localhost:#{bypass.port}/echo.api/cert.pem"

    Bypass.expect(bypass, "GET", "/echo.api/cert.pem", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/x-pem-file")
      |> Plug.Conn.resp(200, pem)
    end)

    assert {:ok, _} = CertCache.fetch(url)

    # Force expiry by overwriting the entry with a past expires_at.
    [{^url, chain, _}] = :ets.lookup(:ekko_cert_cache, url)
    :ets.insert(:ekko_cert_cache, {url, chain, System.monotonic_time(:millisecond) - 1})

    assert {:ok, _} = CertCache.fetch(url)
  end

  test "propagates download failures" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/echo.api/cert.pem"
    Bypass.down(bypass)

    assert {:error, {:cert_download_failed, _}} = CertCache.fetch(url)
  end
end
