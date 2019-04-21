defmodule Paperwork.Notes.Endpoints.Notes do
    use Paperwork.Notes.Server
    use Paperwork.Helpers.Response

    pipeline do
        plug Paperwork.Auth.Plug.SessionLoader
    end

    namespace :notes do

        get do
            global_id = conn
                        |> Paperwork.Auth.Session.get_global_id()

            response = Paperwork.Collections.Note.list()
                       |> Paperwork.Collections.Note.current_version(global_id)

            conn
            |> resp(response)
        end

        desc "Create Note"
        params do
            requires :title,       type: String
            optional :body,        type: String
            requires :attachments, type: List[String]
            requires :tags,        type: List[String]
            requires :path,        type: String
        end
        post do
            global_id = conn
                        |> Paperwork.Auth.Session.get_global_id()

            response = params
                       |> Paperwork.Collections.Note.create_using_version(global_id)
                       |> Paperwork.Collections.Note.current_version(global_id)

            conn
            |> resp(response)
        end

        route_param :id do
            get do
                global_id = conn
                            |> Paperwork.Auth.Session.get_global_id()

                response = params[:id]
                           |> Paperwork.Collections.Note.show
                           |> Paperwork.Collections.Note.current_version(global_id)

                conn
                |> resp(response)
            end

            desc "Update Note"
            params do
                requires :title,       type: String
                optional :body,        type: String
                requires :attachments, type: List[String]
                requires :tags,        type: List[String]
                requires :path,        type: String
            end
            put do
                global_id = conn
                            |> Paperwork.Auth.Session.get_global_id()

                response = params
                           |> Paperwork.Collections.Note.update_using_version(global_id)
                           |> Paperwork.Collections.Note.current_version(global_id)

                conn
                |> resp(response)
            end
        end

    end
end
