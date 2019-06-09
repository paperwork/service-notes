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
            optional :ids,                 type: String
        end
        get do
            global_id =
                conn
                |> Paperwork.Auth.Session.get_global_id()

            query =
                %{}
                |> Paperwork.Collections.Note.query_updated_since(params |> Map.get(:updated_since))
                |> Paperwork.Collections.Note.query_ids(params |> Map.get(:ids))

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

                case response do
                    {:ok, note} ->
                        response
                            |> Paperwork.Helpers.Journal.api_response_to_journal(
                                params,
                                :create,
                                :note,
                                :user,
                                global_id,
                                note
                                |> Map.get(:access)
                                |> Map.keys
                                |> Enum.map(fn access_id -> access_id |> Paperwork.Id.from_gid() end)
                            )
                    _ ->
                        Logger.warn("Note could not be created")
                end

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

                case response do
                    {:ok, note} ->
                        relevance = case params |> Map.has_key?(:access) do
                            true ->
                                previous_access_ids =
                                    note
                                    |> Map.get(:access)
                                    |> Map.keys
                                    |> Enum.map(fn access_id -> Atom.to_string(access_id) end)

                                new_access_ids =
                                    params
                                    |> Map.get(:access)
                                    |> Map.keys

                                removed_access_ids =
                                    previous_access_ids -- new_access_ids

                                combined_access_ids =
                                    new_access_ids ++ removed_access_ids

                                combined_access_ids
                                |> IO.inspect
                                |> Enum.uniq()
                            false ->
                                note
                                |> Map.get(:access)
                                |> Map.keys
                        end

                        response
                            |> Paperwork.Helpers.Journal.api_response_to_journal(
                                params,
                                :update,
                                :note,
                                :user,
                                global_id,
                                relevance
                                |> Enum.map(fn access_id -> access_id |> Paperwork.Id.from_gid() end)
                            )
                    _ ->
                        Logger.warn("No matching note was found")
                end

                conn
                |> resp(response)
            end
        end

    end
end
