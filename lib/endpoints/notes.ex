defmodule Paperwork.Notes.Endpoints.Notes do
    require Logger
    use Paperwork.Notes.Server
    use Paperwork.Helpers.Response

    pipeline do
        plug Paperwork.Auth.Plug.SessionLoader
    end

    namespace :notes do

        params do
            optional :updated_since,       type: :integer
        end
        get do
            global_id =
                conn
                |> Paperwork.Auth.Session.get_global_id()

            updated_since =
                params
                |> Map.get(:updated_since)

            query =
                %{}
                |> Paperwork.Collections.Note.query_updated_since(updated_since)

            response = case \
                conn
                |> Paperwork.Auth.Session.get_user_role \
            do
                :role_admin ->
                    Paperwork.Collections.Note.list()
                    |> Paperwork.Collections.Note.current_version(global_id)
                _ ->
                    Paperwork.Collections.Note.list(query |> Paperwork.Collections.Note.query_can_read(global_id))
                    |> Paperwork.Collections.Note.current_version(global_id)
            end

            conn
            |> resp(response)
        end

        desc "Create Note"
        params do
            requires :title,       type: String
            requires :body,        type: String
            requires :attachments, type: List[String]
            requires :tags,        type: List[String]
            requires :meta,        type: Map
            requires :path,        type: String
        end
        post do
            global_id =
                conn
                |> Paperwork.Auth.Session.get_global_id()

            response =
                params
                |> Paperwork.Collections.Note.create_using_version(global_id)
                |> Paperwork.Collections.Note.current_version(global_id)
                |> Paperwork.Helpers.Journal.api_response_to_journal(params, :create, :note, :user, global_id)

            conn
            |> resp(response)
        end

        route_param :id do
            get do
                global_id =
                    conn
                    |> Paperwork.Auth.Session.get_global_id()

                response =
                    params[:id]
                    |> Paperwork.Collections.Note.show
                    |> Paperwork.Collections.Note.current_version(global_id)

                conn
                |> resp(response)
            end

            desc "Update Note"
            params do
                requires :version,     type: String
                requires :title,       type: String
                requires :body,        type: String
                requires :attachments, type: List[String]
                requires :tags,        type: List[String]
                requires :meta,        type: Map
                requires :path,        type: String
                optional :access,      type: Map
            end
            put do
                global_id =
                    conn
                    |> Paperwork.Auth.Session.get_global_id()

                response =
                    params
                    |> Paperwork.Collections.Note.update_using_version(global_id)
                    |> Paperwork.Collections.Note.current_version(global_id)
                    |> Paperwork.Helpers.Journal.api_response_to_journal(params, :update, :note, :user, global_id)

                conn
                |> resp(response)
            end
        end

    end
end
