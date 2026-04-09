defmodule Ekko do
  @moduledoc """
  Ekko is an Elixir SDK for building Alexa custom skills as a Plug-based web service.

  The SDK is organized in three layers, mirroring the architecture proven by
  `proto_rune` and `anubis_mcp`:

    * **Transport** (`Ekko.Plug`) — receives HTTP requests, verifies Amazon's
      X.509 certificate chain and RSA-SHA256 signature, parses the JSON body,
      and hands a typed envelope downstream. _(planned for Milestone 3)_

    * **Protocol** (`Ekko.Request.*` and `Ekko.Response.*`) — plain Elixir
      structs modeling every Alexa JSON object. Inbound structs expose
      `from_map/1` parsers; outbound structs expose `to_map/1` serializers.
      Keys are matched and built as hardcoded camelCase strings — no Ecto, no
      validation library, no case conversion. _(Milestone 1, this milestone)_

    * **Domain** (`Ekko.Skill`) — the handler framework: a `Skill` behaviour
      returning lists of handlers/interceptors/error_handlers, a `Handler`
      behaviour with `can_handle?/1` and `handle/1`, and a pipe-friendly
      `ResponseBuilder`. _(planned for Milestone 2)_

  See `PLAN.md` at the project root for the full architectural vision.
  """
end
