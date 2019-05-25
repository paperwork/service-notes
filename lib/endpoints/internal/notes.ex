defmodule Paperwork.Notes.Endpoints.Internal.Notes do
    use Paperwork.Notes.Server
    use Paperwork.Helpers.Response

    pipeline do
    end

    namespace :internal do
        namespace :notes do
            get do
                response = Paperwork.Collections.Note.list()
                conn
                |> resp(response)
            end

            route_param :id do
                get do
                    response = params[:id]
                    |> Paperwork.Collections.Note.show()

                    conn
                    |> resp(response)
                end
            end
        end
    end
end
