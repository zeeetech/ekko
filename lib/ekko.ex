defmodule Ekko do
  @moduledoc """
  Ekko is an Elixir SDK for building Alexa custom skills.

  This module is both the **request context** passed to skill callbacks and
  the **response builder** users pipe through to construct a reply. One
  struct, one namespace — no separate `HandlerInput` / `ResponseBuilder` /
  `Dispatcher` modules to learn.

  ## Writing a skill

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
      end

  ## Driving a skill

      raw_request = JSON.decode!(http_body)
      {:ok, response_map} = Ekko.handle(MyApp.MusicSkill, raw_request)

  `Ekko.handle/2` parses the raw map into `Ekko.Request`, builds an `%Ekko{}`
  context, runs the skill module's lifecycle (`before_request/1` →
  `handle_request/2` → `after_request/2`, with `handle_error/3` on the sad
  path), and merges any session attribute mutations into the final response.
  """

  alias Ekko.AttributesManager
  alias Ekko.Internal.MapUtils
  alias Ekko.Request

  @type t :: %__MODULE__{
          request: Request.t() | nil,
          attributes_manager: AttributesManager.t() | nil,
          version: String.t(),
          session_attributes: map() | nil,
          output_speech: map() | nil,
          card: map() | nil,
          reprompt: map() | nil,
          directives: [map()],
          should_end_session: boolean() | nil
        }

  defstruct request: nil,
            attributes_manager: nil,
            version: "1.0",
            session_attributes: nil,
            output_speech: nil,
            card: nil,
            reprompt: nil,
            directives: [],
            should_end_session: nil

  # ── Construction ────────────────────────────────────────────────────────────

  @doc """
  Builds a fresh `%Ekko{}` context from a parsed request.
  """
  @spec new(Request.t()) :: t()
  def new(%Request{} = request) do
    %__MODULE__{
      request: request,
      attributes_manager: AttributesManager.new(request)
    }
  end

  # ── Top-level entry point ───────────────────────────────────────────────────

  @doc """
  Parses a raw decoded-JSON Alexa request map and runs it through the given
  skill module's full lifecycle.

  Returns the finished response map (already in Alexa wire format) on success.
  """
  @spec handle(skill_module :: module(), raw_request :: map()) ::
          {:ok, map()} | {:error, term()}
  def handle(skill_module, raw_request) when is_atom(skill_module) and is_map(raw_request) do
    with {:ok, request} <- Request.from_map(raw_request) do
      ekko = new(request)
      run_lifecycle(skill_module, ekko, request.request)
    end
  end

  defp run_lifecycle(skill, ekko, inner) do
    with {:ok, ekko} <- skill.before_request(ekko),
         {:ok, response} <- call_handler(skill, inner, ekko),
         {:ok, response} <- validate_response(inner, response),
         {:ok, response} <- skill.after_request(ekko, response) do
      {:ok, merge_session_attributes(response, ekko)}
    else
      {:error, reason} -> skill.handle_error(reason, inner, ekko)
    end
  end

  defp call_handler(skill, inner, ekko) do
    skill.handle_request(inner, ekko)
  end

  defp merge_session_attributes(response, %__MODULE__{attributes_manager: %AttributesManager{session_attributes: attrs}})
       when is_map(attrs) and map_size(attrs) > 0 do
    Map.put_new(response, "sessionAttributes", attrs)
  end

  defp merge_session_attributes(response, _ekko), do: response

  @audio_player_forbidden_fields ["outputSpeech", "card", "reprompt"]

  defp validate_response(%Request.AudioPlayer{}, response) do
    check_audio_response(response)
  end

  defp validate_response(%Request.PlaybackController{}, response) do
    check_audio_response(response)
  end

  defp validate_response(_inner, response), do: {:ok, response}

  defp check_audio_response(%{"response" => inner} = response) do
    case Enum.find(@audio_player_forbidden_fields, &Map.has_key?(inner, &1)) do
      nil -> {:ok, response}
      field -> {:error, {:invalid_audio_player_response, field}}
    end
  end

  defp check_audio_response(response), do: {:ok, response}

  # ── Speech ──────────────────────────────────────────────────────────────────

  @doc """
  Sets the spoken response. Auto-detects SSML markup and wraps in `<speak>`
  tags when needed; plain text becomes a `PlainText` output speech.
  """
  @spec speak(t(), String.t()) :: t()
  def speak(%__MODULE__{} = ekko, text) when is_binary(text) do
    %{ekko | output_speech: build_speech(text)}
  end

  @doc """
  Sets the reprompt speech. Same SSML auto-detection as `speak/2`.
  """
  @spec reprompt(t(), String.t()) :: t()
  def reprompt(%__MODULE__{} = ekko, text) when is_binary(text) do
    %{ekko | reprompt: %{"outputSpeech" => build_speech(text)}}
  end

  defp build_speech(text) do
    case detect_speech(text) do
      {:plain_text, txt} -> %{"type" => "PlainText", "text" => txt}
      {:ssml, ssml} -> %{"type" => "SSML", "ssml" => ssml}
    end
  end

  defp detect_speech(text) do
    cond do
      String.starts_with?(text, "<speak>") and String.ends_with?(text, "</speak>") ->
        {:ssml, text}

      String.contains?(text, "<") and String.contains?(text, ">") ->
        {:ssml, "<speak>" <> text <> "</speak>"}

      true ->
        {:plain_text, text}
    end
  end

  # ── Cards ───────────────────────────────────────────────────────────────────

  @doc """
  Sets a `Simple` card with a title and content body.
  """
  @spec card(t(), :simple, String.t(), String.t()) :: t()
  def card(%__MODULE__{} = ekko, :simple, title, content) when is_binary(title) and is_binary(content) do
    %{ekko | card: %{"type" => "Simple", "title" => title, "content" => content}}
  end

  @doc """
  Sets a `Standard` card with a title, body text, and optional images.

  `image` is either `nil` or `%{small: url, large: url}` (one or both keys).
  """
  @spec card(t(), :standard, String.t(), String.t(), map() | nil) :: t()
  def card(%__MODULE__{} = ekko, :standard, title, text, image \\ nil) when is_binary(title) and is_binary(text) do
    base = %{"type" => "Standard", "title" => title, "text" => text}

    card_map =
      case image do
        nil ->
          base

        %{} = img ->
          image_map =
            %{}
            |> MapUtils.maybe_put("smallImageUrl", Map.get(img, :small))
            |> MapUtils.maybe_put("largeImageUrl", Map.get(img, :large))

          if image_map == %{}, do: base, else: Map.put(base, "image", image_map)
      end

    %{ekko | card: card_map}
  end

  @doc """
  Sets a `LinkAccount` card.
  """
  @spec link_account_card(t()) :: t()
  def link_account_card(%__MODULE__{} = ekko) do
    %{ekko | card: %{"type" => "LinkAccount"}}
  end

  @doc """
  Sets an `AskForPermissionsConsent` card with the given permission scopes.
  """
  @spec ask_for_permissions_card(t(), [String.t()]) :: t()
  def ask_for_permissions_card(%__MODULE__{} = ekko, permissions) when is_list(permissions) do
    %{ekko | card: %{"type" => "AskForPermissionsConsent", "permissions" => permissions}}
  end

  # ── Session control ─────────────────────────────────────────────────────────

  @doc "Sets whether Alexa should end the session after this response."
  @spec should_end_session(t(), boolean()) :: t()
  def should_end_session(%__MODULE__{} = ekko, value) when is_boolean(value) do
    %{ekko | should_end_session: value}
  end

  @doc """
  Replaces the session attributes that will be written back to Alexa.
  """
  @spec with_session_attributes(t(), map()) :: t()
  def with_session_attributes(%__MODULE__{} = ekko, attrs) when is_map(attrs) do
    %{ekko | session_attributes: attrs}
  end

  # ── Directives ──────────────────────────────────────────────────────────────

  @doc """
  Appends a raw directive map. Escape hatch for directives Ekko hasn't modeled.
  """
  @spec add_directive(t(), map()) :: t()
  def add_directive(%__MODULE__{directives: directives} = ekko, directive) when is_map(directive) do
    %{ekko | directives: directives ++ [directive]}
  end

  @doc """
  Appends an `AudioPlayer.Play` directive.

  ## Options

    * `:expected_previous_token` — required when `behavior` is `:enqueue` and
      you want Alexa to validate the queue tail.
    * `:metadata` — optional map with `:title`, `:subtitle`, `:art` (URL),
      `:background_image` (URL).
  """
  @spec add_audio_player_play(
          t(),
          :replace_all | :replace_enqueued | :enqueue,
          String.t(),
          String.t(),
          non_neg_integer(),
          keyword()
        ) :: t()
  def add_audio_player_play(%__MODULE__{} = ekko, behavior, url, token, offset, opts \\ [])
      when behavior in [:replace_all, :replace_enqueued, :enqueue] and is_binary(url) and is_binary(token) and
             is_integer(offset) and offset >= 0 do
    stream =
      MapUtils.maybe_put(
        %{"url" => url, "token" => token, "offsetInMilliseconds" => offset},
        "expectedPreviousToken",
        Keyword.get(opts, :expected_previous_token)
      )

    audio_item = MapUtils.maybe_put(%{"stream" => stream}, "metadata", build_metadata(Keyword.get(opts, :metadata)))

    directive = %{
      "type" => "AudioPlayer.Play",
      "playBehavior" => audio_play_behavior(behavior),
      "audioItem" => audio_item
    }

    add_directive(ekko, directive)
  end

  defp build_metadata(nil), do: nil

  defp build_metadata(%{} = meta) do
    %{}
    |> MapUtils.maybe_put("title", Map.get(meta, :title))
    |> MapUtils.maybe_put("subtitle", Map.get(meta, :subtitle))
    |> MapUtils.maybe_put("art", build_image_source(Map.get(meta, :art)))
    |> MapUtils.maybe_put("backgroundImage", build_image_source(Map.get(meta, :background_image)))
    |> case do
      empty when map_size(empty) == 0 -> nil
      m -> m
    end
  end

  defp build_image_source(nil), do: nil
  defp build_image_source(url) when is_binary(url), do: %{"sources" => [%{"url" => url}]}

  defp audio_play_behavior(:replace_all), do: "REPLACE_ALL"
  defp audio_play_behavior(:replace_enqueued), do: "REPLACE_ENQUEUED"
  defp audio_play_behavior(:enqueue), do: "ENQUEUE"

  @doc """
  Appends an `AudioPlayer.Stop` directive.
  """
  @spec add_audio_player_stop(t()) :: t()
  def add_audio_player_stop(%__MODULE__{} = ekko) do
    add_directive(ekko, %{"type" => "AudioPlayer.Stop"})
  end

  @doc """
  Appends an `AudioPlayer.ClearQueue` directive.
  """
  @spec add_audio_player_clear_queue(t(), :clear_enqueued | :clear_all) :: t()
  def add_audio_player_clear_queue(%__MODULE__{} = ekko, behavior) when behavior in [:clear_enqueued, :clear_all] do
    add_directive(ekko, %{
      "type" => "AudioPlayer.ClearQueue",
      "clearBehavior" => clear_behavior(behavior)
    })
  end

  defp clear_behavior(:clear_enqueued), do: "CLEAR_ENQUEUED"
  defp clear_behavior(:clear_all), do: "CLEAR_ALL"

  @doc """
  Appends a `Dialog.Delegate` directive.
  """
  @spec add_delegate_directive(t(), map() | nil) :: t()
  def add_delegate_directive(%__MODULE__{} = ekko, updated_intent \\ nil) do
    add_directive(
      ekko,
      MapUtils.maybe_put(%{"type" => "Dialog.Delegate"}, "updatedIntent", updated_intent)
    )
  end

  @doc """
  Appends a `Dialog.ElicitSlot` directive for the given slot name.
  """
  @spec add_elicit_slot_directive(t(), String.t(), map() | nil) :: t()
  def add_elicit_slot_directive(%__MODULE__{} = ekko, slot_name, updated_intent \\ nil) when is_binary(slot_name) do
    base = %{"type" => "Dialog.ElicitSlot", "slotToElicit" => slot_name}
    add_directive(ekko, MapUtils.maybe_put(base, "updatedIntent", updated_intent))
  end

  @doc """
  Appends a `Dialog.ConfirmSlot` directive for the given slot name.
  """
  @spec add_confirm_slot_directive(t(), String.t(), map() | nil) :: t()
  def add_confirm_slot_directive(%__MODULE__{} = ekko, slot_name, updated_intent \\ nil) when is_binary(slot_name) do
    base = %{"type" => "Dialog.ConfirmSlot", "slotToConfirm" => slot_name}
    add_directive(ekko, MapUtils.maybe_put(base, "updatedIntent", updated_intent))
  end

  @doc """
  Appends a `Dialog.ConfirmIntent` directive.
  """
  @spec add_confirm_intent_directive(t(), map() | nil) :: t()
  def add_confirm_intent_directive(%__MODULE__{} = ekko, updated_intent \\ nil) do
    add_directive(
      ekko,
      MapUtils.maybe_put(%{"type" => "Dialog.ConfirmIntent"}, "updatedIntent", updated_intent)
    )
  end

  # ── Build ───────────────────────────────────────────────────────────────────

  @doc """
  Produces the finished Alexa response map. The shape matches Amazon's
  [request and response JSON reference](https://developer.amazon.com/docs/custom-skills/request-and-response-json-reference.html).
  """
  @spec build(t()) :: map()
  def build(%__MODULE__{} = ekko) do
    response =
      %{}
      |> MapUtils.maybe_put("outputSpeech", ekko.output_speech)
      |> MapUtils.maybe_put("card", ekko.card)
      |> MapUtils.maybe_put("reprompt", ekko.reprompt)
      |> MapUtils.maybe_put_list("directives", ekko.directives)
      |> MapUtils.maybe_put("shouldEndSession", ekko.should_end_session)

    MapUtils.maybe_put(%{"version" => ekko.version, "response" => response}, "sessionAttributes", ekko.session_attributes)
  end
end
