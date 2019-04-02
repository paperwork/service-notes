use Mix.Config

config :paperwork_service_notes, Paperwork.Server,
  adapter: Plug.Cowboy,
  plug: Paperwork,
  scheme: :http,
  port: 8880

config :paperwork_service_notes,
  maru_servers: [Paperwork.Server]

config :logger,
  backends: [:console]
