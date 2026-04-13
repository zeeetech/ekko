# Ekko

Elixir SDK for building [Amazon Alexa custom skills](https://developer.amazon.com/en-US/docs/alexa/custom-skills/understanding-custom-skills.html).

One struct, one namespace. Parse requests, pattern-match on the inner type,
pipe a response together, and let `Ekko.Plug` handle verification and
serialization.

## Installation

Add `ekko` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ekko, "~> 0.1.0"}
  ]
end
```

## Quick start

Define a skill:

```elixir
defmodule MyApp.GreeterSkill do
  use Ekko.Skill

  @impl Ekko.Skill
  def handle_request(%Ekko.Request.Launch{}, ekko) do
    response =
      ekko
      |> Ekko.speak("Welcome! Ask me anything.")
      |> Ekko.reprompt("Go ahead, I'm listening.")
      |> Ekko.should_end_session(false)
      |> Ekko.build()

    {:ok, response}
  end

  def handle_request(%Ekko.Request.Intent{intent: %{name: "HelloIntent"}}, ekko) do
    response =
      ekko
      |> Ekko.speak("Hello from Ekko!")
      |> Ekko.should_end_session(true)
      |> Ekko.build()

    {:ok, response}
  end
end
```

Mount the plug in your router:

```elixir
# In a Phoenix endpoint or standalone Plug router
forward "/alexa", Ekko.Plug, skill: MyApp.GreeterSkill
```

That's it. Ekko handles request verification, JSON parsing, skill dispatch,
and response serialization.

## Features

- **Request parsing** — typed structs for `LaunchRequest`, `IntentRequest`,
  `SessionEndedRequest`, all five `AudioPlayer` playback events,
  `PlaybackController` commands, and `System.ExceptionEncountered`
- **Response builder** — speech (plain text / SSML), cards, directives,
  session attributes, AudioPlayer playback controls
- **Skill lifecycle** — `before_request/1`, `handle_request/2`,
  `after_request/2`, `handle_error/3` with sensible defaults
- **Request verification** — full 5-step Amazon pipeline (URL validation,
  cert chain download + caching, X.509 trust + SAN check, RSA-SHA256
  signature, timestamp tolerance)
- **AudioPlayer integration** — `Ekko.AudioPlayer.Playlist` for playlist
  state with shuffle, loop, and cursor; pluggable `PlaylistStore` behaviour
  for persistence
- **Response constraints** — `AudioPlayer` and `PlaybackController` handlers
  are prevented from returning forbidden fields (`outputSpeech`, `card`,
  `reprompt`) at the framework level

## Configuration

```elixir
# config/config.exs
config :ekko,
  verify_requests: true,                # false in test
  cert_cache_ttl_ms: 86_400_000,        # 24h
  timestamp_tolerance_seconds: 150,
  playlist_store: Ekko.AudioPlayer.PlaylistStore.ETS
```

## Guides

- [Getting Started](guides/getting-started.md)
- [AudioPlayer Integration](guides/audio-player.md)
- [Request Verification](guides/request-verification.md)

## License

Apache-2.0. See [LICENSE](LICENSE) for details.
