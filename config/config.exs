use Mix.Config

config :paperwork_service_notes, Paperwork.Server,
    adapter: Plug.Cowboy,
    plug: Paperwork,
    scheme: :http,
    ip: {0,0,0,0},
    port: {:system, :integer, "PORT", 8882}

config :paperwork_service_notes,
    maru_servers: [Paperwork.Server]

config :paperwork, :internal,
    configs: {:system, :string, "INTERNAL_RESOURCE_CONFIGS", "http://localhost:8880/internal/configs"},
    users:   {:system, :string, "INTERNAL_RESOURCE_USERS",   "http://localhost:8881/internal/users"},
    notes:   {:system, :string, "INTERNAL_RESOURCE_NOTES",   "http://localhost:8882/internal/notes"}

config :logger,
    backends: [:console]
