defmodule Paperwork.Notes.Application do
    use Application

    def start(_type, _args) do
        case Code.ensure_loaded(ExSync) do
            {:module, ExSync = mod} ->
                mod.start()
            {:error, _} ->
                :ok
        end

        children = [
            Paperwork.Ex,
            Paperwork.Notes.Server,
            {Mongo, [name: :mongo, database: "notes", pool: DBConnection.Poolboy]}
        ]

        opts = [strategy: :one_for_one, name: Paperwork.Notes.Supervisor]
        Supervisor.start_link(children, opts)
    end
end
