defmodule Ekko.Verifier do
  @moduledoc """
  Behaviour for verifying an inbound Alexa HTTP request.

  Verification fuses signature checking and JSON decoding into one step:
  the verifier reads the raw body and the request headers, runs whatever
  pipeline it implements, and returns the decoded request map (so the
  caller doesn't decode the body twice).

  ## Implementations

    * `Ekko.Verifier.Default` — full 5-step pipeline (URL validation, cert
      download/cache, chain validation, RSA-SHA256 signature, timestamp
      window). Used in production.
    * `Ekko.Verifier.NoOp` — decodes the body and skips verification.
      Selected when `config :ekko, verify_requests: false` (e.g. in tests).

  Tests can also Mox this behaviour to inject arbitrary verifier outcomes
  into `Ekko.Plug` without going through real crypto.
  """

  @type headers :: [{String.t(), String.t()}]

  @callback verify(raw_body :: binary(), headers()) ::
              {:ok, decoded_request :: map()} | {:error, term()}
end
