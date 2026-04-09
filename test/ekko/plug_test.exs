defmodule Ekko.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Ekko.Test.Fixtures

  @moduletag capture_log: true

  defmodule TestSkill do
    @moduledoc false
    use Ekko.Skill

    @impl Ekko.Skill
    def handle_request(%Ekko.Request.Launch{}, ekko) do
      response =
        ekko
        |> Ekko.speak("hello")
        |> Ekko.should_end_session(true)
        |> Ekko.build()

      {:ok, response}
    end
  end

  defp call_plug(body, headers \\ [{"content-type", "application/json"}], opts \\ [skill: TestSkill]) do
    :post
    |> conn("/", body)
    |> then(fn conn -> Enum.reduce(headers, conn, fn {k, v}, c -> put_req_header(c, k, v) end) end)
    |> Ekko.Plug.call(Ekko.Plug.init(opts))
  end

  test "happy path with NoOp verifier returns 200 and a valid response" do
    body = JSON.encode!(Fixtures.launch_request())
    conn = call_plug(body)

    assert conn.status == 200
    assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers

    decoded = JSON.decode!(conn.resp_body)
    assert decoded["version"] == "1.0"
    assert decoded["response"]["outputSpeech"]["text"] == "hello"
    assert decoded["response"]["shouldEndSession"] == true
  end

  test "malformed JSON returns 400" do
    conn = call_plug("not json")
    assert conn.status == 400
  end

  defmodule StubVerifier do
    @moduledoc false
    @behaviour Ekko.Verifier

    @impl true
    def verify(_body, _headers), do: {:error, :signature_invalid}
  end

  test "signature_invalid stub returns 400" do
    body = JSON.encode!(Fixtures.launch_request())
    conn = call_plug(body, [{"content-type", "application/json"}], skill: TestSkill, verifier: StubVerifier)
    assert conn.status == 400
  end

  defmodule TimestampStub do
    @moduledoc false
    @behaviour Ekko.Verifier

    @impl true
    def verify(_body, _headers), do: {:error, :timestamp_too_old}
  end

  test "timestamp_too_old returns 400" do
    body = JSON.encode!(Fixtures.launch_request())
    conn = call_plug(body, [{"content-type", "application/json"}], skill: TestSkill, verifier: TimestampStub)
    assert conn.status == 400
  end

  defmodule DownloadStub do
    @moduledoc false
    @behaviour Ekko.Verifier

    @impl true
    def verify(_body, _headers), do: {:error, {:cert_download_failed, :nxdomain}}
  end

  test "cert_download_failed returns 503" do
    body = JSON.encode!(Fixtures.launch_request())
    conn = call_plug(body, [{"content-type", "application/json"}], skill: TestSkill, verifier: DownloadStub)
    assert conn.status == 503
  end
end
