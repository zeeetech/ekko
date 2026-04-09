defmodule Ekko.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Ekko.Finch},
      Ekko.Crypto.CertCache
    ]

    opts = [strategy: :one_for_one, name: Ekko.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
