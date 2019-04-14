use Mix.Config

config :paperwork_service_notes, Paperwork.Server,
    adapter: Plug.Cowboy,
    plug: Paperwork,
    scheme: :http,
    ip: {0,0,0,0},
    port: {:system, :integer, "PORT", 8882}

config :paperwork_service_notes,
    maru_servers: [Paperwork.Server]

config :logger,
    backends: [:console]
