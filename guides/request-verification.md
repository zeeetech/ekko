# Request Verification

Alexa requires skills hosted as web services to verify every incoming
request. Ekko handles this automatically through `Ekko.Plug`.

## The 5-step pipeline

`Ekko.Verifier.Default` implements the full verification pipeline
[Amazon mandates](https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html):

1. **URL validation** — the `SignatureCertChainUrl` header must point to
   `https://s3.amazonaws.com/echo.api/...` on port 443. Path traversal
   attacks (`../`) are normalized and rejected.

2. **Certificate download** — the signing certificate chain is fetched over
   HTTPS via Finch. Downloaded chains are cached in ETS by URL with a
   configurable TTL (default: 24 hours).

3. **Chain validation** — the certificate chain is validated against the
   OS-trusted CA store. The leaf certificate's Subject Alternative Name
   must include `echo-api.amazon.com`.

4. **Signature verification** — the `Signature-256` header (Base64-encoded
   RSA-SHA256) is verified against the raw request body using the leaf
   certificate's public key.

5. **Timestamp check** — the request's `request.timestamp` must be within
   the configured tolerance (default: 150 seconds) of the current UTC time.

If any step fails, `Ekko.Plug` returns an appropriate HTTP error status
(400 for validation failures, 503 for certificate download failures).

## Configuration

```elixir
# config/config.exs
config :ekko,
  verify_requests: true,
  cert_cache_ttl_ms: 86_400_000,        # 24 hours
  timestamp_tolerance_seconds: 150       # Amazon's default
```

## Disabling for tests

In your test environment, disable verification so you can send raw JSON
without signing:

```elixir
# config/test.exs
config :ekko, verify_requests: false
```

When disabled, `Ekko.Plug` uses `Ekko.Verifier.NoOp`, which simply decodes
the JSON body and returns it without any cryptographic checks.

## Overriding the verifier

You can pass a custom verifier module when mounting the plug:

```elixir
forward "/alexa", Ekko.Plug,
  skill: MyApp.Skill,
  verifier: MyApp.CustomVerifier
```

Your module must implement the `Ekko.Verifier` behaviour:

```elixir
defmodule MyApp.CustomVerifier do
  @behaviour Ekko.Verifier

  @impl true
  def verify(raw_body, headers) do
    # raw_body: the raw HTTP body as a binary
    # headers: list of {name, value} tuples (lowercased names)
    #
    # Return {:ok, decoded_map} on success
    # Return {:error, reason} on failure
  end
end
```

The verifier receives the raw body and all request headers. It must return
`{:ok, decoded_request_map}` — the decoded map is passed directly to
`Ekko.handle/2`, so the body is only parsed once.

## Certificate caching

`Ekko.Crypto.CertCache` stores parsed certificate chains in a public ETS
table keyed by URL. The table is owned by a tiny Agent process, so it survives process restarts.

Cache entries expire after `cert_cache_ttl_ms` (monotonic time). On miss
or expiry, the chain is re-downloaded via `Ekko.Crypto.CertDownloader`
(a thin Finch wrapper) and re-parsed.

## Error mapping

`Ekko.Plug` maps verification errors to HTTP status codes:

| Error | Status |
|-------|--------|
| `:invalid_cert_url` | 400 |
| `{:cert_chain_invalid, _}` | 400 |
| `:san_mismatch` | 400 |
| `:signature_invalid` | 400 |
| `:timestamp_too_old` | 400 |
| `:timestamp_in_future` | 400 |
| `{:missing_header, _}` | 400 |
| `{:cert_download_failed, _}` | 503 |
| `{:cert_download_status, _}` | 503 |
| anything else | 500 |
