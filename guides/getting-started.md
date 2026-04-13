# Getting Started

This guide walks you through building your first Alexa skill with Ekko.

## Installation

Add Ekko to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:ekko, "~> 0.1.0"}
  ]
end
```

Ekko starts its own supervision tree automatically (Finch for certificate
downloads, ETS caches for cert chains and playlists). No manual setup needed.

## Define a skill

A skill is a module that uses `Ekko.Skill` and implements `handle_request/2`.
The first argument is a typed request struct; the second is an `%Ekko{}`
context you pipe through the response builder:

```elixir
defmodule MyApp.GreeterSkill do
  use Ekko.Skill

  alias Ekko.Request

  @impl Ekko.Skill
  def handle_request(%Request.Launch{}, ekko) do
    response =
      ekko
      |> Ekko.speak("Welcome to my skill! What can I help you with?")
      |> Ekko.reprompt("I'm still here. Try asking me something.")
      |> Ekko.should_end_session(false)
      |> Ekko.build()

    {:ok, response}
  end

  def handle_request(%Request.Intent{intent: %{name: "GreetIntent"}}, ekko) do
    response =
      ekko
      |> Ekko.speak("Hello there!")
      |> Ekko.card(:simple, "Greeting", "Hello there!")
      |> Ekko.should_end_session(true)
      |> Ekko.build()

    {:ok, response}
  end

  def handle_request(%Request.SessionEnded{}, ekko) do
    {:ok, Ekko.build(ekko)}
  end
end
```

Ekko injects a catch-all clause that returns `{:error, :no_handler_match}`
for any request type you don't handle. You can customize error recovery by
implementing `handle_error/3`:

```elixir
@impl Ekko.Skill
def handle_error(reason, _request, ekko) do
  response =
    ekko
    |> Ekko.speak("Sorry, something went wrong.")
    |> Ekko.should_end_session(true)
    |> Ekko.build()

  {:ok, response}
end
```

## Mount the Plug

Ekko ships a single `Ekko.Plug` that handles request verification, JSON
parsing, skill dispatch, and response serialization. Mount it in your
router:

### Phoenix

```elixir
# lib/my_app_web/router.ex
scope "/alexa" do
  forward "/", Ekko.Plug, skill: MyApp.GreeterSkill
end
```

### Standalone Plug/Bandit

```elixir
defmodule MyApp.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/alexa", to: Ekko.Plug, init_opts: [skill: MyApp.GreeterSkill]
end

# Start Bandit
{:ok, _} = Bandit.start_link(plug: MyApp.Router, port: 4000)
```

## Configuration

```elixir
# config/config.exs
config :ekko,
  verify_requests: true,
  cert_cache_ttl_ms: 86_400_000,
  timestamp_tolerance_seconds: 150
```

For local development and tests, disable verification:

```elixir
# config/test.exs
config :ekko, verify_requests: false
```

## Testing your skill

You can test without HTTP by calling `Ekko.handle/2` directly:

```elixir
defmodule MyApp.GreeterSkillTest do
  use ExUnit.Case

  alias Ekko.Test.RequestFixtures

  test "LaunchRequest returns a welcome message" do
    assert {:ok, response} = Ekko.handle(MyApp.GreeterSkill, RequestFixtures.launch_request())
    assert response["response"]["outputSpeech"]["text"] =~ "Welcome"
  end
end
```

`Ekko.Test.RequestFixtures` ships with the library and provides decoded-JSON
maps for every request type Alexa sends.

## Working with slots

Intent slots are parsed into `%Ekko.Request.Slot{}` structs, keyed by name:

```elixir
def handle_request(%Request.Intent{intent: %{name: "OrderIntent", slots: slots}}, ekko) do
  item = slots |> Map.get("item", %{}) |> Map.get(:value, "unknown")

  response =
    ekko
    |> Ekko.speak("Ordering #{item} for you.")
    |> Ekko.should_end_session(true)
    |> Ekko.build()

  {:ok, response}
end
```

## Lifecycle hooks

The full lifecycle is: `before_request/1` -> `handle_request/2` ->
`after_request/2`, with `handle_error/3` on the error path. All callbacks
except `handle_request/2` have default implementations that pass through.

```elixir
@impl Ekko.Skill
def before_request(ekko) do
  # Log, set up session state, etc.
  {:ok, ekko}
end

@impl Ekko.Skill
def after_request(_ekko, response) do
  # Post-process the response map
  {:ok, response}
end
```

## Next steps

- [AudioPlayer Integration](audio-player.md) — build streaming music skills
- [Request Verification](request-verification.md) — understand the security pipeline
