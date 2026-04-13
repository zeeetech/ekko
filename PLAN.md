# AlexaKit — Alexa Skills SDK for Elixir

> **A complete Elixir SDK for building Alexa custom skills, hosted as a Plug-based web service with first-class AudioPlayer support.**

This plan draws directly from Zoey's established SDK patterns in [proto_rune][proto_rune] (three-layer architecture, behaviours, pipe-friendly builders) and [anubis-mcp][anubis-mcp] (component registration, transport abstraction), applies them to the full [Alexa Skills Kit][ask-overview] request/response lifecycle, and fills the gap left by every existing Elixir Alexa library — all of which are abandoned (2016–2018), lack AudioPlayer and Dialog support, and use Poison instead of the native `JSON` module.

The SDK will live at [`github.com/zeetech/alexa_kit`][zeetech-gh] and ship as a single hex package.

---

## Table of contents

- [Why a new SDK and what it replaces](#why-a-new-sdk-and-what-it-replaces)
- [Three-layer architecture mirrors proto\_rune](#three-layer-architecture-mirrors-proto_rune)
- [Project structure and mix layout](#project-structure-and-mix-layout)
- [Handler system: behaviours over macros](#handler-system-behaviours-over-macros)
- [ResponseBuilder uses pipe-friendly composition](#responsebuilder-uses-pipe-friendly-composition)
- [AudioPlayer support is structural, not bolted on](#audioplayer-support-is-structural-not-bolted-on)
- [Request parsing: hardcoded keys, no case conversion](#request-parsing-hardcoded-keys-no-case-conversion)
- [Structs and validation: manual construction, no Ecto](#structs-and-validation-manual-construction-no-ecto)
- [Request signature verification uses Erlang's :public\_key](#request-signature-verification-uses-erlangs-public_key)
- [Milestones with clear deliverables](#milestones-with-clear-deliverables)
- [Technical decisions to discuss](#technical-decisions-to-discuss)
- [Patterns drawn from Zoey's existing projects](#patterns-drawn-from-zoeys-existing-projects)

---

## Why a new SDK and what it replaces

Every existing Elixir Alexa library is dead. The most-downloaded package, [`alexa`][hex-alexa] by Colin Harris (**420K hex downloads**, last updated June 2016), provides basic intent routing but zero signature verification, no AudioPlayer, no Dialog directives, and uses the deprecated Poison JSON library. The only signature verification library, [`alexa_request_verifier`][hex-alexa-verifier], broke in June 2018 when Amazon switched Certificate Authorities and was never fixed. A fork ([`pylon_alexa_request_verifier`][hex-pylon-verifier]) patched the CA issue but has not been updated since. **No existing library supports AudioPlayer, Dialog management, SSML building, or modern Alexa features.**

The [ASK SDK for Node.js][ask-nodejs] and [Java][ask-java] both follow a consistent architecture: a `RequestEnvelope` wraps all incoming data, a `HandlerInput` provides context to handlers, `RequestHandler` modules use a `canHandle`/`handle` dispatch pattern, a fluent `ResponseBuilder` constructs responses, and interceptors run before/after handlers. This SDK translates those patterns into idiomatic Elixir using Zoey's proven approaches — **with behaviours and explicit function composition instead of macros and DSLs**.

---

## Three-layer architecture mirrors proto\_rune

Following the [proto_rune][proto_rune] model where Transport (XRPC) sits below Protocol (Atproto) which sits below the Domain API (Bsky), AlexaKit uses three layers:

**Layer 1 — Transport (`AlexaKit.Plug`)**: The Plug adapter that receives HTTP requests, caches the raw body for signature verification, validates Amazon's [X.509 certificate chain and RSA-SHA256 signature][alexa-web-service], checks the request timestamp (within **150 seconds**), parses JSON via the native `JSON` module (Elixir 1.19+/OTP 28), and passes the verified `RequestEnvelope` struct downstream. This layer is pure infrastructure — no Alexa domain logic.

**Layer 2 — Protocol (`AlexaKit.Request` / `AlexaKit.Response`)**: Typed Elixir structs mapping every [Alexa JSON object][alexa-request-response-ref] — `RequestEnvelope`, `Session`, `Context`, `LaunchRequest`, `IntentRequest`, `SessionEndedRequest`, all five [`AudioPlayer.*` request types][alexa-audioplayer-ref], `Intent`, `Slot`, `Resolution`. On the response side: `ResponseEnvelope`, `OutputSpeech`, `Card` (Simple, Standard, LinkAccount, AskForPermissionsConsent), `Reprompt`, and all directive types. These are lightweight structs with `@type t()` specs — **built manually with explicit `from_map/1` and `to_map/1` functions, matching hardcoded camelCase keys directly** — no Ecto, no validation library, no case conversion. Same approach as [proto_rune's structs][proto_rune].

**Layer 3 — Domain (`AlexaKit.Skill`)**: The handler framework. Defines the `AlexaKit.Handler` behaviour (`can_handle?/1` + `handle/1`), the `AlexaKit.HandlerInput` context struct (wrapping request envelope, response builder, and session attributes manager), the `AlexaKit.ResponseBuilder` pipe-friendly API, and `AlexaKit.Skill` as a **behaviour** (not a macro) that wires handlers, interceptors, and error handlers through explicit function calls.

```
AlexaKit (public facade)
├── AlexaKit.Plug (Layer 1: Transport)
│   ├── AlexaKit.Plug.Router
│   ├── AlexaKit.Plug.BodyCache
│   └── AlexaKit.Plug.RequestVerifier
├── AlexaKit.Request (Layer 2: Protocol — inbound)
│   ├── AlexaKit.Request.Envelope
│   ├── AlexaKit.Request.Session
│   ├── AlexaKit.Request.Context
│   ├── AlexaKit.Request.Launch
│   ├── AlexaKit.Request.Intent
│   ├── AlexaKit.Request.SessionEnded
│   └── AlexaKit.Request.AudioPlayer
├── AlexaKit.Response (Layer 2: Protocol — outbound)
│   ├── AlexaKit.Response.Envelope
│   ├── AlexaKit.Response.OutputSpeech
│   ├── AlexaKit.Response.Card
│   └── AlexaKit.Response.Directive
├── AlexaKit.Skill (Layer 3: Domain — behaviour, not macro)
│   ├── AlexaKit.Handler (behaviour)
│   ├── AlexaKit.HandlerInput
│   ├── AlexaKit.ResponseBuilder
│   ├── AlexaKit.Interceptor (behaviour)
│   └── AlexaKit.ErrorHandler (behaviour)
└── AlexaKit.Crypto (signature verification internals)
    ├── AlexaKit.Crypto.CertValidator
    ├── AlexaKit.Crypto.SignatureVerifier
    └── AlexaKit.Crypto.CertCache
```

---

## Project structure and mix layout

```
alexa_kit/
├── lib/
│   ├── alexa_kit.ex                          # Public facade module
│   ├── alexa_kit/
│   │   ├── plug/
│   │   │   ├── router.ex                     # Plug.Router for /alexa endpoint
│   │   │   ├── body_cache.ex                 # Custom body_reader for raw body preservation
│   │   │   └── request_verifier.ex           # Plug that runs full verification pipeline
│   │   ├── request/
│   │   │   ├── envelope.ex                   # %Envelope{version, session, context, request}
│   │   │   ├── session.ex                    # %Session{session_id, application, user, new?, attributes}
│   │   │   ├── context.ex                    # %Context{system, audio_player}
│   │   │   ├── system.ex                     # %System{application, user, device, api_endpoint, api_access_token}
│   │   │   ├── launch.ex                     # %Launch{request_id, timestamp, locale}
│   │   │   ├── intent.ex                     # %Intent{request_id, intent, dialog_state, ...}
│   │   │   ├── session_ended.ex              # %SessionEnded{reason, error}
│   │   │   ├── audio_player.ex               # PlaybackStarted/Stopped/NearlyFinished/Failed/Finished
│   │   │   └── slot.ex                       # %Slot{name, value, confirmation_status, resolutions}
│   │   ├── response/
│   │   │   ├── envelope.ex                   # %Envelope{version, session_attributes, response}
│   │   │   ├── output_speech.ex              # %OutputSpeech{type, text, ssml, play_behavior}
│   │   │   ├── card.ex                       # Simple, Standard, LinkAccount, AskForPermissions
│   │   │   ├── reprompt.ex                   # %Reprompt{output_speech}
│   │   │   ├── directive.ex                  # Protocol + implementations for all directive types
│   │   │   ├── audio_player_directive.ex     # Play, Stop, ClearQueue directives
│   │   │   └── dialog_directive.ex           # Delegate, ElicitSlot, ConfirmSlot, ConfirmIntent
│   │   ├── skill.ex                          # @behaviour: handlers/0, interceptors/0, error_handlers/0
│   │   ├── handler.ex                        # @behaviour: can_handle?/1, handle/1
│   │   ├── handler_input.ex                  # %HandlerInput{request_envelope, response_builder, attrs}
│   │   ├── response_builder.ex               # Pipe-friendly builder
│   │   ├── interceptor.ex                    # @behaviour: process/1 (req), process/2 (resp)
│   │   ├── error_handler.ex                  # @behaviour: can_handle?/2, handle/2
│   │   ├── dispatcher.ex                     # Runs the full handler pipeline
│   │   ├── attributes_manager.ex             # Request/session/persistent attribute management
│   │   ├── crypto/
│   │   │   ├── cert_validator.ex             # URL validation, cert chain, SAN check
│   │   │   ├── signature_verifier.ex         # RSA-SHA256 via :public_key.verify/4
│   │   │   └── cert_cache.ex                 # ETS-backed certificate cache with TTL
│   │   └── application.ex                    # OTP Application: starts cert cache ETS table
├── test/
│   ├── alexa_kit/
│   │   ├── plug/
│   │   │   ├── request_verifier_test.exs
│   │   │   └── router_test.exs
│   │   ├── request/
│   │   │   └── envelope_test.exs
│   │   ├── response/
│   │   │   ├── response_builder_test.exs
│   │   │   └── envelope_test.exs
│   │   ├── crypto/
│   │   │   ├── cert_validator_test.exs
│   │   │   └── signature_verifier_test.exs
│   │   ├── dispatcher_test.exs
│   │   └── skill_test.exs
│   ├── support/
│   │   ├── fixtures.ex                       # AlexaKit.Test.Fixtures module
│   │   └── test_helpers.ex
│   └── test_helper.exs
├── config/
│   ├── config.exs
│   └── test.exs
├── examples/
│   ├── hello_world/                          # Minimal skill example
│   └── audio_player/                         # Full AudioPlayer playlist example
├── guides/
│   ├── getting_started.md
│   ├── audio_player.md
│   └── request_verification.md
├── .github/workflows/ci.yml
├── .formatter.exs
├── .credo.exs
├── .dialyzerignore.exs
├── flake.nix
├── flake.lock
├── .envrc
├── CLAUDE.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE                                   # MIT
├── README.md
├── mix.exs
└── mix.lock
```

### mix.exs configuration

```elixir
defmodule AlexaKit.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/zeetech/alexa_kit"

  def project do
    [
      app: :alexa_kit,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:public_key, :crypto]],
      preferred_cli_env: [dialyzer: :dev, credo: :dev]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :public_key, :crypto, :inets, :ssl],
      mod: {AlexaKit.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:finch, "~> 0.18"},
      {:bandit, "~> 1.0", optional: true},
      {:plug_cowboy, "~> 2.7", optional: true},
      # test / dev
      {:mox, "~> 1.2", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:stream_data, "~> 1.0", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
```

Key dependency decisions:

- **No Jason** — Elixir 1.19 / OTP 28 ships the native [`JSON`][elixir-json] module. Zero-dep JSON.
- **Finch** for certificate downloads (matching Zoey's HTTP client preference from [proto_rune][proto_rune]).
- **Plug** as the only required web dependency — Bandit and Cowboy are optional; users bring their own server.
- **No Ecto, no Peri, no validation library** — structs are built manually with explicit `from_map/1` functions and pattern-matching guards, same as proto\_rune. Validation happens through match failures and explicit `{:error, reason}` returns.
- **No Recase or key conversion library** — keys are matched/built as hardcoded camelCase strings at the struct boundary.

---

## Handler system: behaviours over macros

Following the [anubis-mcp][anubis-mcp] pattern of behaviour-first design (rather than `use`-macro DSLs), the SDK defines pure behaviours with no `__using__` macros. Developers implement behaviours explicitly:

### The Handler behaviour

```elixir
defmodule AlexaKit.Handler do
  @type handler_input :: AlexaKit.HandlerInput.t()

  @callback can_handle?(handler_input()) :: boolean()
  @callback handle(handler_input()) :: {:ok, AlexaKit.Response.Envelope.t()} | {:error, term()}
end
```

### The Skill behaviour

Instead of a `use AlexaKit.Skill` macro with `handler MyModule` DSL calls, `AlexaKit.Skill` is a plain behaviour with callbacks that return lists:

```elixir
defmodule AlexaKit.Skill do
  @callback handlers() :: [module()]
  @callback request_interceptors() :: [module()]
  @callback response_interceptors() :: [module()]
  @callback error_handlers() :: [module()]

  # Optional callbacks with defaults
  @optional_callbacks request_interceptors: 0,
                      response_interceptors: 0,
                      error_handlers: 0
end
```

Implementing a skill is a regular module with `@behaviour`:

```elixir
defmodule MyApp.MusicSkill do
  @behaviour AlexaKit.Skill

  @impl true
  def handlers do
    [
      MyApp.Handlers.Launch,
      MyApp.Handlers.PlayMusic,
      MyApp.Handlers.AudioPlayer,
      MyApp.Handlers.Help,
      MyApp.Handlers.Stop,
      MyApp.Handlers.Fallback
    ]
  end

  @impl true
  def request_interceptors, do: [MyApp.Interceptors.Logging]

  @impl true
  def response_interceptors, do: [MyApp.Interceptors.SaveAttributes]

  @impl true
  def error_handlers, do: [MyApp.ErrorHandlers.Generic]
end
```

### The Dispatcher

`AlexaKit.Dispatcher` is a **plain function module** that takes a skill module and a `HandlerInput`, then runs the full pipeline — request interceptors → first-match handler dispatch → response interceptors → error handling. No GenServer, no hidden state:

```elixir
defmodule AlexaKit.Dispatcher do
  @spec dispatch(module(), AlexaKit.HandlerInput.t()) ::
          {:ok, AlexaKit.Response.Envelope.t()} | {:error, term()}
  def dispatch(skill_module, handler_input) do
    with {:ok, input} <- run_request_interceptors(skill_module, handler_input),
         {:ok, response} <- find_and_run_handler(skill_module, input),
         {:ok, response} <- run_response_interceptors(skill_module, input, response) do
      {:ok, response}
    else
      {:error, reason} -> run_error_handlers(skill_module, handler_input, reason)
    end
  end

  defp find_and_run_handler(skill_module, input) do
    skill_module.handlers()
    |> Enum.find(&(&1.can_handle?(input)))
    |> case do
      nil -> {:error, :no_handler_found}
      handler -> handler.handle(input)
    end
  end
end
```

### A concrete handler — pattern matching on request type

```elixir
defmodule MyApp.Handlers.Launch do
  @behaviour AlexaKit.Handler

  @impl true
  def can_handle?(%{request_envelope: %{request: %AlexaKit.Request.Launch{}}}), do: true
  def can_handle?(_), do: false

  @impl true
  def handle(input) do
    response =
      AlexaKit.HandlerInput.response_builder(input)
      |> AlexaKit.ResponseBuilder.speak("Welcome to Music Player!")
      |> AlexaKit.ResponseBuilder.reprompt("What would you like to play?")
      |> AlexaKit.ResponseBuilder.should_end_session(false)
      |> AlexaKit.ResponseBuilder.build()

    {:ok, response}
  end
end
```

### A concrete handler — pattern matching on intent name

```elixir
defmodule MyApp.Handlers.PlayMusic do
  @behaviour AlexaKit.Handler

  @impl true
  def can_handle?(%{request_envelope: %{request: %AlexaKit.Request.Intent{intent: %{name: "PlayMusicIntent"}}}}), do: true
  def can_handle?(_), do: false

  @impl true
  def handle(input) do
    song_name =
      input.request_envelope.request.intent.slots
      |> Map.get("songName", %{})
      |> Map.get(:value, "something random")

    response =
      AlexaKit.HandlerInput.response_builder(input)
      |> AlexaKit.ResponseBuilder.speak("Now playing #{song_name}")
      |> AlexaKit.ResponseBuilder.add_audio_player_play(
           :replace_all,
           "https://example.com/#{song_name}.mp3",
           "track-001",
           0
         )
      |> AlexaKit.ResponseBuilder.build()

    {:ok, response}
  end
end
```

This approach: **zero macros, zero DSL, zero compile-time magic**. Handlers are plain modules. The skill is a plain module. The dispatcher is a plain function. Everything is explicit and traceable, matching the anubis-mcp philosophy.

---

## ResponseBuilder uses pipe-friendly composition

Following proto\_rune's `RichText.new() |> RichText.text(...) |> RichText.build()` pattern:

```elixir
# Basic response
AlexaKit.HandlerInput.response_builder(input)
|> ResponseBuilder.speak("Welcome to my skill!")
|> ResponseBuilder.reprompt("What would you like to do?")
|> ResponseBuilder.card(:simple, "Welcome", "Hello there!")
|> ResponseBuilder.should_end_session(false)
|> ResponseBuilder.build()

# AudioPlayer response
AlexaKit.HandlerInput.response_builder(input)
|> ResponseBuilder.speak("Now playing your song")
|> ResponseBuilder.add_audio_player_play(
     :replace_all,
     "https://example.com/song.mp3",
     "track-001",
     0,
     metadata: %{title: "My Song", subtitle: "Artist"}
   )
|> ResponseBuilder.build()

# Dialog delegation
AlexaKit.HandlerInput.response_builder(input)
|> ResponseBuilder.add_delegate_directive()
|> ResponseBuilder.build()
```

The builder accumulates state in a `%ResponseBuilder{}` struct, and `build/1` produces a `%Response.Envelope{}` ready for JSON serialization. `speak/2` automatically wraps text in `<speak>` SSML tags when SSML markup is detected, matching the [Node.js SDK's behavior][ask-nodejs].

---

## AudioPlayer support is structural, not bolted on

AudioPlayer requests differ fundamentally from session-based requests: they carry **no `session` object**, only `context` with `System` and the audio player state. The SDK handles this at the struct level — `%Request.Envelope{}` has `session` as an optional field (`Session.t() | nil`), and the parser correctly handles both session and non-session request types.

Five [AudioPlayer request types][alexa-audioplayer-ref] are modeled as distinct structs under `AlexaKit.Request.AudioPlayer`:

- `%PlaybackStarted{token, offset_in_milliseconds}` — playback began
- `%PlaybackFinished{token, offset_in_milliseconds}` — stream completed
- `%PlaybackStopped{token, offset_in_milliseconds}` — user or directive stopped playback
- `%PlaybackNearlyFinished{token, offset_in_milliseconds}` — time to enqueue next track
- `%PlaybackFailed{token, error, current_playback_state}` — with nested `%PlaybackError{type, message}`

Three [AudioPlayer directives][alexa-audioplayer-ref] are modeled under `AlexaKit.Response.Directive.AudioPlayer`:

- `%Play{play_behavior, audio_item}` where `audio_item` contains `%Stream{url, token, expected_previous_token, offset_in_milliseconds}` and optional `%Metadata{title, subtitle, art, background_image}`
- `%Stop{}`
- `%ClearQueue{clear_behavior}` with `:clear_enqueued` or `:clear_all`

The ResponseBuilder **enforces Alexa's response constraints**: AudioPlayer request handlers cannot include `output_speech`, `card`, `reprompt`, or `should_end_session` — only `Stop` and `ClearQueue` directives. The builder raises a clear error at build time if a handler violates these constraints.

For playlist management, the SDK provides an optional `AlexaKit.AudioPlayer.Queue` GenServer that tracks playlist state per user via `Registry`. The `PlaybackNearlyFinished` handler pattern is documented with a working example that responds with an `ENQUEUE` play directive, setting `expected_previous_token` to [chain tracks][alexa-long-form-audio].

---

## Request parsing: hardcoded keys, no case conversion

Instead of a generic camelCase → snake\_case key converter, each struct's `from_map/1` function matches hardcoded camelCase string keys directly from the decoded JSON. This gives **total control** over which fields are extracted, avoids mangling user-provided values (session attribute keys, slot values), and matches the [proto\_rune approach][proto_rune] where struct fields map explicitly to wire format keys.

```elixir
defmodule AlexaKit.Request.Session do
  @type t :: %__MODULE__{
    session_id: String.t(),
    new?: boolean(),
    attributes: map(),
    application: map(),
    user: map()
  }

  defstruct [:session_id, :new?, :application, :user, attributes: %{}]

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{
    "sessionId" => session_id,
    "new" => new?,
    "application" => application,
    "user" => user
  } = raw) do
    {:ok,
     %__MODULE__{
       session_id: session_id,
       new?: new?,
       attributes: Map.get(raw, "attributes", %{}),
       application: application,
       user: user
     }}
  end

  def from_map(_), do: {:error, :invalid_session}
end
```

Outbound serialization uses the same explicit approach — `to_map/1` produces camelCase string-keyed maps that `JSON.encode!/1` handles directly:

```elixir
defmodule AlexaKit.Response.OutputSpeech do
  defstruct [:type, :text, :ssml, :play_behavior]

  def to_map(%__MODULE__{type: :ssml} = speech) do
    %{"type" => "SSML", "ssml" => speech.ssml}
    |> maybe_put("playBehavior", speech.play_behavior)
  end

  def to_map(%__MODULE__{type: :plain_text} = speech) do
    %{"type" => "PlainText", "text" => speech.text}
    |> maybe_put("playBehavior", speech.play_behavior)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

The `"type"` field on requests drives polymorphic dispatch in the parser:

| Alexa `type` value | Struct module |
|---|---|
| `"LaunchRequest"` | `AlexaKit.Request.Launch` |
| `"IntentRequest"` | `AlexaKit.Request.Intent` |
| `"SessionEndedRequest"` | `AlexaKit.Request.SessionEnded` |
| `"AudioPlayer.PlaybackStarted"` | `AlexaKit.Request.AudioPlayer.PlaybackStarted` |
| `"AudioPlayer.PlaybackFinished"` | `AlexaKit.Request.AudioPlayer.PlaybackFinished` |
| `"AudioPlayer.PlaybackStopped"` | `AlexaKit.Request.AudioPlayer.PlaybackStopped` |
| `"AudioPlayer.PlaybackNearlyFinished"` | `AlexaKit.Request.AudioPlayer.PlaybackNearlyFinished` |
| `"AudioPlayer.PlaybackFailed"` | `AlexaKit.Request.AudioPlayer.PlaybackFailed` |

---

## Structs and validation: manual construction, no Ecto

Following the [proto\_rune][proto_rune] precedent — which builds all AT Protocol structs manually without Ecto changesets or the [Peri][peri] validation library — AlexaKit takes the same approach:

- **`from_map/1`** returns `{:ok, struct}` or `{:error, reason}` using pattern matching on required keys. If the map doesn't match, it fails with a descriptive error atom.
- **No changesets** — Alexa's JSON schema is well-defined and stable. The structs either match or they don't. There's no user input validation scenario (like form data) where changeset error accumulation adds value.
- **No Peri schemas** — while [Peri][peri] is excellent for complex validation rules, Alexa requests have a fixed schema dictated by Amazon. Pattern matching in `from_map/1` is sufficient and keeps the dependency count at zero.
- **Nested construction** — parent `from_map/1` calls delegate to child `from_map/1` functions. Failures propagate via `with`:

```elixir
defmodule AlexaKit.Request.Envelope do
  defstruct [:version, :session, :context, :request]

  def from_map(%{"version" => version, "context" => context_raw, "request" => request_raw} = raw) do
    with {:ok, context} <- AlexaKit.Request.Context.from_map(context_raw),
         {:ok, request} <- parse_request(request_raw) do
      session =
        case Map.get(raw, "session") do
          nil -> nil
          session_raw -> elem(AlexaKit.Request.Session.from_map(session_raw), 1)
        end

      {:ok, %__MODULE__{version: version, session: session, context: context, request: request}}
    end
  end

  defp parse_request(%{"type" => "LaunchRequest"} = raw),
    do: AlexaKit.Request.Launch.from_map(raw)
  defp parse_request(%{"type" => "IntentRequest"} = raw),
    do: AlexaKit.Request.Intent.from_map(raw)
  defp parse_request(%{"type" => "SessionEndedRequest"} = raw),
    do: AlexaKit.Request.SessionEnded.from_map(raw)
  defp parse_request(%{"type" => "AudioPlayer." <> _} = raw),
    do: AlexaKit.Request.AudioPlayer.from_map(raw)
  defp parse_request(%{"type" => type}),
    do: {:error, {:unknown_request_type, type}}
end
```

If Zoey later decides validation needs grow (e.g., validating outbound responses before sending, or adding developer-facing schema checks), Peri can be introduced as an **optional dependency** for a dev-mode validation layer without changing the core struct construction.

---

## Request signature verification uses Erlang's :public\_key

The verification pipeline runs as a Plug before request parsing, following Amazon's [mandated process for hosting a custom skill as a web service][alexa-web-service]:

**Step 1 — URL validation**: The `SignatureCertChainUrl` header value must have HTTPS scheme, `s3.amazonaws.com` host (case-insensitive), path starting with `/echo.api/` (case-sensitive), and port 443 or absent. The path is normalized to collapse `..` segments before checking.

**Step 2 — Certificate download with caching**: Certificates are fetched via [Finch][finch] and cached in an ETS table (`AlexaKit.Crypto.CertCache`) keyed by URL with a configurable TTL (default **24 hours**). The ETS table is owned by the Application supervisor to survive process crashes.

**Step 3 — Certificate chain validation**: PEM data is decoded via [`:public_key.pem_decode/1`][erlang-public-key], each entry decoded with `:public_key.pkix_decode_cert/2` using the `:otp` format. The chain is reversed and validated against OS-trusted CAs via `:public_key.cacerts_get/0` (OTP 25+). The signing certificate's SAN is checked for `echo-api.amazon.com` using `:public_key.pkix_verify_hostname/2`.

**Step 4 — Signature verification**: The `Signature-256` header is Base64-decoded, and `:public_key.verify(raw_body, :sha256, decoded_signature, public_key)` verifies the RSA-SHA256 signature against the raw request body.

**Step 5 — Timestamp validation**: The `request.timestamp` field is parsed via `DateTime.from_iso8601/1` and compared against `DateTime.utc_now/0`. Requests older than **150 seconds** are rejected.

The raw body is preserved using a custom `body_reader` function passed to `Plug.Parsers`:

```elixir
defmodule AlexaKit.Plug.BodyCache do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | (&1 || [])])
    {:ok, body, conn}
  end
end
```

Verification is disabled in test environments via application config (`config :alexa_kit, verify_requests: false`), and the verifier module sits behind a behaviour so it can be mocked with [Mox][mox].

---

## Milestones with clear deliverables

### Milestone 1 — Foundation (weeks 1–2)

Mix project scaffolding, Nix flake, CI, and all request/response structs.

**Deliverables**: `mix new alexa_kit`, complete `Request.Envelope` struct hierarchy including all AudioPlayer types, `Response.Envelope` and all nested response types, `from_map/1` parsers matching hardcoded camelCase keys, `to_map/1` serializers producing camelCase output, JSON round-trip using native `JSON` module, comprehensive struct tests with fixtures from [Alexa's JSON reference][alexa-request-response-ref].

**Exit criterion**: round-trip test passes — parse an Alexa JSON request fixture into structs via `from_map/1`, then serialize a response back to valid Alexa JSON via `to_map/1` + `JSON.encode!/1`.

### Milestone 2 — Handler framework (weeks 3–4)

The skill behaviour, handler behaviour, response builder, interceptors, error handlers, and dispatcher.

**Deliverables**: `AlexaKit.Skill` behaviour with `handlers/0`, `request_interceptors/0`, `response_interceptors/0`, `error_handlers/0` callbacks; `AlexaKit.Handler` behaviour; `AlexaKit.HandlerInput` struct; `AlexaKit.ResponseBuilder` with all builder methods including AudioPlayer and Dialog directives; `AlexaKit.Interceptor` and `AlexaKit.ErrorHandler` behaviours; `AlexaKit.Dispatcher` with first-match dispatch pipeline.

**Exit criterion**: a test skill module implementing `@behaviour AlexaKit.Skill` correctly dispatches a `LaunchRequest` and an `IntentRequest`, builder produces valid response JSON.

### Milestone 3 — Plug adapter and signature verification (weeks 5–6)

The transport layer.

**Deliverables**: `AlexaKit.Plug.Router` (standalone `Plug.Router`), `AlexaKit.Plug.BodyCache`, `AlexaKit.Plug.RequestVerifier` (full 5-step verification), `AlexaKit.Crypto.CertCache` (ETS-backed), `AlexaKit.Crypto.CertValidator`, `AlexaKit.Crypto.SignatureVerifier`. Uses [Bypass][bypass] to mock Amazon's certificate endpoint in tests, [Mox][mox] to mock the verifier in handler tests.

**Exit criterion**: end-to-end test — POST a signed Alexa request to the Plug, verify signature, parse, dispatch to handler, return valid response.

### Milestone 4 — AudioPlayer deep integration (week 7)

AudioPlayer-specific handler helpers, queue management, and the playlist example.

**Deliverables**: `AlexaKit.AudioPlayer.Queue` GenServer for optional playlist state tracking, response constraint enforcement (AudioPlayer handlers can only return AudioPlayer directives), convenience functions for common patterns (`enqueue_next/3`, `stop_playback/0`, `clear_and_play/2`), complete AudioPlayer example in `examples/audio_player/`.

**Exit criterion**: the audio player example implements a full playlist skill with play, pause, resume, next, previous, and shuffle — all using the [AudioPlayer interface][alexa-audioplayer-ref].

### Milestone 5 — Polish, docs, and hex release (week 8)

Documentation, guides, and release.

**Deliverables**: [ex\_doc][ex_doc] documentation for every public module, getting started guide, AudioPlayer guide, request verification guide, `AlexaKit.Test.Fixtures` module for users, property-based tests with [StreamData][stream_data] for JSON round-tripping, Dialyzer clean, Credo clean, hex.pm package publication.

**Exit criterion**: `mix hex.publish` succeeds, hexdocs are live, a new user can follow the getting started guide to build and deploy a skill.

---

## Technical decisions to discuss

### Package naming

The name `alexa` is taken on hex.pm ([Colin Harris's abandoned package][hex-alexa]). `alexa_kit` mirrors "ASK" (Alexa Skills Kit) and follows Elixir naming conventions. The top-level module would be `AlexaKit`. Alternatives: `alexa_skills` for explicitness, or `askex` for brevity. Zoey's naming pattern uses descriptive words (`peri`, `nexus`) or compound names (`proto_rune`, `anubis_mcp`).

### Persistent attributes adapter

The [ASK SDK for Node.js][ask-nodejs] supports DynamoDB for persistent attributes via an adapter pattern. AlexaKit should define a `PersistenceAdapter` behaviour but not ship a DynamoDB implementation — users implement their own for ETS, Redis, Postgres, or DynamoDB. This follows Zoey's "explicit over implicit" philosophy. Whether a first-party `alexa_kit_dynamodb` package is worth building depends on demand.

### Bandit vs Cowboy default

Both are supported as optional dependencies. [Bandit][bandit] is pure Elixir, faster, and is Phoenix's default since 1.7.11. Recommend Bandit in documentation but support both. Whether to vendor one as a hard dependency or keep both optional (requiring users to add one to their deps) is an open question.

### Future Peri integration

If validation needs grow beyond "match or fail" (e.g., developer-mode response validation with detailed error messages, schema introspection for documentation generation), [Peri][peri] could be added as an **optional dependency** behind a `config :alexa_kit, validation: :peri` flag. The struct construction itself wouldn't change — Peri would wrap `from_map/1` with richer error reporting.

### Native JSON module nuances

Elixir 1.19's `JSON` module covers encode/decode but may lack some niceties Jason provides (protocol-based encoding, custom encoder implementations). If this becomes a limitation for struct serialization, we can define a simple `JSON.Encoder` protocol implementation or fall back to explicit `to_map/1` → `JSON.encode!/1` (the planned approach already avoids needing protocol dispatch).

---

## Patterns drawn from Zoey's existing projects

The **three-layer architecture** directly maps from [proto\_rune][proto_rune]: Transport → Protocol → Domain becomes Plug → Request/Response structs → Skill framework. Each layer has clean interfaces and can be used independently — the structs work without the Plug adapter (for Lambda deployments or testing), and the Plug adapter works without the skill framework (for raw Plug handlers).

The **behaviour-first, no-macro design** comes from [anubis-mcp][anubis-mcp]'s architecture where components implement behaviours and are registered through explicit function returns, not compile-time macro magic. AlexaKit's `Skill` behaviour returning `handlers/0` as a list of modules mirrors this pattern exactly.

The **pipe-friendly builder** pattern mirrors proto\_rune's `RichText` builder: `new() |> operation() |> operation() |> build()`. The `ResponseBuilder` is an immutable struct that accumulates response components.

The **manual struct construction with hardcoded keys** follows proto\_rune's approach to AT Protocol types — no schema DSL, no validation library, just explicit `from_map/1` functions that pattern-match on known wire-format keys.

**Explicit state passing** (no global singletons) follows Zoey's core principle. `HandlerInput` is passed explicitly to every handler and interceptor. Session attributes are read from the request and written to the response — no hidden GenServer managing session state.

**`{:ok, result} | {:error, reason}` tuples** are used everywhere: handler returns, verification results, struct parsing. The `Dispatcher` pipeline uses `with` chains for the happy path.

**Dev tooling** matches Zoey's setup: Nix flake for reproducible environments, `.envrc` for direnv, CLAUDE.md for AI development context, `.formatter.exs` / `.credo.exs` / `.dialyzerignore.exs`, GitHub Actions CI with `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`, and `mix test`.

**Testing with Mox and Bypass** follows [anubis-mcp's testing patterns][anubis-mcp]. The `CertificateVerifier` behaviour enables mocking in handler tests. Bypass mocks Amazon's certificate endpoint for integration tests. `AlexaKit.Test.Fixtures` provides factory functions for users to test their own skills.

---

## Reference links

<!-- Project references -->
[proto_rune]: https://github.com/zoedsoupe/proto_rune
[anubis-mcp]: https://github.com/zoedsoupe/anubis-mcp
[peri]: https://github.com/zoedsoupe/peri
[zeetech-gh]: https://github.com/zeetech

<!-- Alexa documentation -->
[ask-overview]: https://developer.amazon.com/en-US/docs/alexa/ask-overviews/what-is-the-alexa-skills-kit.html
[ask-nodejs]: https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-nodejs/handle-requests.html
[ask-java]: https://developer.amazon.com/en-US/docs/alexa/alexa-skills-kit-sdk-for-java/develop-your-first-skill.html
[alexa-request-response-ref]: https://developer.amazon.com/docs/custom-skills/request-and-response-json-reference.html
[alexa-request-types]: https://developer.amazon.com/en-US/docs/alexa/custom-skills/request-types-reference.html
[alexa-audioplayer-ref]: https://developer.amazon.com/en-US/docs/alexa/custom-skills/audioplayer-interface-reference.html
[alexa-long-form-audio]: https://developer.amazon.com/en-US/docs/alexa/custom-skills/use-long-form-audio.html
[alexa-web-service]: https://developer.amazon.com/en-US/docs/alexa/custom-skills/host-a-custom-skill-as-a-web-service.html
[alexa-session-attrs]: https://developer.amazon.com/en-US/blogs/alexa/alexa-skills-kit/2018/05/using-session-attributes-in-your-alexa-skill-to-enhance-the-voice-experience

<!-- Existing Elixir packages -->
[hex-alexa]: https://hex.pm/packages/alexa
[hex-alexa-verifier]: https://hex.pm/packages/alexa_request_verifier
[hex-pylon-verifier]: https://libraries.io/hex/pylon_alexa_request_verifier
[alexa-verifier-gh]: https://github.com/col/alexa_verifier

<!-- Erlang/Elixir references -->
[erlang-public-key]: https://www.erlang.org/doc/apps/public_key/public_key.html
[elixir-json]: https://hexdocs.pm/elixir/JSON.html
[elixir-forum-x509]: https://elixirforum.com/t/x-509-request-cert-chain-validation-plug-for-alexa-skills/4463

<!-- Dependencies -->
[finch]: https://github.com/sneako/finch
[bandit]: https://github.com/mtrudel/bandit
[mox]: https://github.com/dashbitco/mox
[bypass]: https://github.com/PSPDFKit-labs/bypass
[ex_doc]: https://github.com/elixir-lang/ex_doc
[stream_data]: https://github.com/whatyouhide/stream_data