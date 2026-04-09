defmodule Ekko.Skill do
  @moduledoc """
  Behaviour for an Alexa skill module.

  An Ekko skill is a single module that pattern-matches on the inner request
  struct, much like a `GenServer` pattern-matches on messages. There is no
  separate `Handler` / `Interceptor` / `ErrorHandler` module hierarchy — one
  skill module owns the full request lifecycle.

  ## Required callback

    * `c:handle_request/2` — pattern-matches on the inner request struct
      (`Ekko.Request.Launch`, `Ekko.Request.Intent`,
      `Ekko.Request.AudioPlayer`, `Ekko.Request.SessionEnded`) and returns a
      finished response map.

  ## Optional callbacks (default implementations injected by `use`)

    * `c:before_request/1` — runs before `handle_request/2`. Default returns
      `{:ok, ekko}` unchanged.
    * `c:after_request/2` — runs after `handle_request/2` succeeds. Default
      returns `{:ok, response}` unchanged.
    * `c:handle_error/3` — runs when `handle_request/2` returns
      `{:error, term()}`. Default propagates the error.

  All optional callbacks are `defoverridable` after `use Ekko.Skill`, so you
  override only the ones you need.

  ## Catch-all

  `use Ekko.Skill` installs an `@before_compile` hook that appends a final
  `handle_request(_, _)` clause returning `{:error, :no_handler_match}`. You
  never have to write a fallback clause yourself — the dispatcher will route
  unhandled requests to `c:handle_error/3`, which by default surfaces
  `{:error, :no_handler_match}`.

  ## Example

      defmodule MyApp.MusicSkill do
        use Ekko.Skill

        alias Ekko.Request

        @impl Ekko.Skill
        def handle_request(%Request.Launch{}, ekko) do
          response =
            ekko
            |> Ekko.speak("Welcome to Music Player!")
            |> Ekko.reprompt("What would you like to play?")
            |> Ekko.should_end_session(false)
            |> Ekko.build()

          {:ok, response}
        end

        def handle_request(%Request.Intent{intent: %{name: "PlayMusicIntent"}}, ekko) do
          response =
            ekko
            |> Ekko.speak("Now playing your song")
            |> Ekko.add_audio_player_play(:replace_all, "https://example.com/song.mp3", "track-001", 0)
            |> Ekko.build()

          {:ok, response}
        end

        def handle_request(%Request.AudioPlayer{event: :nearly_finished}, ekko) do
          # enqueue the next track…
          {:ok, Ekko.build(ekko)}
        end

        @impl Ekko.Skill
        def before_request(ekko) do
          require Logger
          Logger.info("alexa request: \#{inspect(ekko.request.request)}")
          {:ok, ekko}
        end
      end
  """

  @type response :: map()

  @callback handle_request(request :: struct(), Ekko.t()) ::
              {:ok, response()} | {:error, term()}

  @callback before_request(Ekko.t()) :: {:ok, Ekko.t()} | {:error, term()}

  @callback after_request(Ekko.t(), response()) :: {:ok, response()} | {:error, term()}

  @callback handle_error(error :: term(), request :: struct(), Ekko.t()) ::
              {:ok, response()} | {:error, term()}

  @optional_callbacks before_request: 1, after_request: 2, handle_error: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour Ekko.Skill
      @before_compile Ekko.Skill

      @impl Ekko.Skill
      def before_request(ekko), do: {:ok, ekko}

      @impl Ekko.Skill
      def after_request(_ekko, response), do: {:ok, response}

      @impl Ekko.Skill
      def handle_error(error, _request, _ekko), do: {:error, error}

      defoverridable before_request: 1, after_request: 2, handle_error: 3
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl Ekko.Skill
      def handle_request(_request, _ekko), do: {:error, :no_handler_match}
    end
  end
end
