defmodule Paperwork.Collections.Note do
    require Logger

    @collection "notes"
    @privates []
    @enforce_keys []
    @type t :: %__MODULE__{
        id: BSON.ObjectId.t() | nil,
        version: String.t(),
        versions: %{
            required(String.t()) => %{
                title: String.t(),
                body: String.t(),
                attachments: [String.t()],
                tags: [String.t()],
                meta: Map.t(),
                created_by: String.t(),
                created_at: DateTime.t()
            }
        },
        access: %{
            required(String.t()) => %{
                path: String.t(),
                can_read: Boolean.t(),
                can_write: Boolean.t(),
                can_share: Boolean.t(),
                can_leave: Boolean.t(),
                can_change_permissions: Boolean.t()
            }
        },
        created_at: DateTime.t(),
        updated_at: DateTime.t(),
        deleted_at: DateTime.t() | nil
    }
    defstruct \
        id: nil,
        version: "",
        versions: %{
        },
        access: %{
        },
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        deleted_at: nil

    use Paperwork.Collections

    @permissions_default_owner %{
        can_read: true,
        can_write: true,
        can_share: true,
        can_leave: false,
        can_change_permissions: true
    }

    @spec show(id :: BSON.ObjectId.t) :: {:ok, %__MODULE__{}} | {:notfound, nil}
    def show(%BSON.ObjectId{} = id) when is_map(id) do
        show(%__MODULE__{:id => id})
    end

    @spec show(id :: String.t) :: {:ok, %__MODULE__{}} | {:notfound, nil}
    def show(id) when is_binary(id) do
        show(%__MODULE__{:id => id})
    end

    @spec show(model :: __MODULE__.t) :: {:ok, %__MODULE__{}} | {:notfound, nil}
    def show(%__MODULE__{:id => _} = model) do
        collection_find(model, :id)
        |> strip_privates
    end

    @spec list() :: {:ok, [%__MODULE__{}]} | {:notfound, nil}
    def list() do
        %{}
        |> collection_find(true)
        |> strip_privates
    end

    @spec list(query :: Map.t) :: {:ok, [%__MODULE__{}]} | {:notfound, nil}
    def list(%{} = query) when is_map(query) do
        query
        |> collection_find(true)
        |> strip_privates
    end

    @spec create_using_version(version :: Map.t, global_id :: String.t) :: {:ok, %__MODULE__{}} | {:error, String.t}
    def create_using_version(%{title: _title, body: _body, attachments: _attachments, tags: _tags, path: path} = version, global_id) when is_map(version) and is_binary(global_id) do
        version_id = Mongo.object_id() |> BSON.ObjectId.encode!()

        %__MODULE__{
            version: version_id,
            versions: %{
                String.to_atom(version_id) =>
                    version
                    |> Map.delete(:path)
                    |> Map.put(:created_by, global_id)
                    |> Map.put(:created_at, DateTime.utc_now())
            },
            access: %{
                String.to_atom(global_id) => Map.merge(@permissions_default_owner, %{
                    path: path,
                })
            },
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now(),
            deleted_at: nil
        }
        |> collection_insert
        |> strip_privates
    end

    def query_ids(%{} = query, nil) do
        query
    end

    def query_ids(%{} = query, ids) when is_binary(ids) do
        ids_list =
            String.split(ids, ",", trim: true)
            |> Enum.dedup()
            |> Enum.reduce([], fn maybe_id, new_list ->
                case maybe_id do
                    nil -> new_list
                    id -> Enum.concat(new_list, [id |> Paperwork.Id.from_gid() |> Paperwork.Id.to_objectid(:id)])
                end
            end)

        query
        |> Map.put(
            :_id,
            %{"$in": ids_list}
        )
    end

    def query_can_read(%{} = query, global_id) when is_binary(global_id) do
        query
        |> Map.put(
            :"access.#{global_id}.can_read",
            true
        )
    end

    def query_updated_since(%{} = query, nil) do
        query
    end

    def query_updated_since(%{} = query, epoch) when is_integer(epoch) do
        query
        |> Map.put(
            :updated_at,
            %{"$gte": DateTime.from_unix!(epoch, :second)}
        )
    end

    defp query_with_access(%{} = query, %{} = version, false, global_id) when is_binary(global_id) do
        query
    end

    defp query_with_access(%{} = query, %{} = version, true, global_id) when is_binary(global_id) do
        query
        |> Map.put(
            :"access.#{global_id}.can_change_permissions",
            true
        )
    end

    defp set_with_access(%{} = set, %{} = version, false, global_id) when is_binary(global_id) do
        set
    end

    defp set_with_access(%{} = set, %{} = version, true, global_id) when is_binary(global_id) do
        set
        |> Map.merge(
            Map.get(version, :access)
            |> steamroll_access()
            |> Map.to_list()
            |> Enum.reduce(%{},
                fn {k, v}, merged_map ->
                    split_key =
                        k
                        |> String.split(".")

                    access_gid =
                        split_key
                        |> List.first()

                    access_permission_name =
                        split_key
                        |> List.last()

                    with \
                        {:ok, _} <- validate_access_gid(access_gid),
                        {:ok, _} <- validate_access_permission(access_permission_name, v) do
                            Map.merge(merged_map,
                                %{
                                    String.to_atom("access.#{k}") => v
                                })
                    else
                        err ->
                            Logger.error("Could not add access changeset: #{err}")
                            merged_map
                    end
                end)
        )
    end

    defp validate_access_gid(global_id) do
        with \
            {:ok, _} <- Paperwork.Id.validate_gid(global_id),
            {:ok, user} <- Paperwork.Internal.Request.user(global_id) do
                {:ok, user}
        else
            err ->
                Logger.error("Validation of access GID failed: #{err}")
                {:error, "Supplied GID (#{global_id}) seems to be invalid"}
        end
    end

    defp validate_access_permission(permission_name, permission_value) when is_binary(permission_name) and is_boolean(permission_value) do
        found_permission_name = @permissions_default_owner
        |> Map.to_list()
        |> List.keyfind(String.to_atom(permission_name), 0)

        case found_permission_name do
            nil -> {:error, "Permission invalid"}
            valid -> {:ok, {permission_name, permission_value}}
        end
    end

    defp validate_access_permission(permission_name, permission_value), do: {:error, "Permission invalid"}

    @spec update_using_version(version :: Map.t, global_id :: String.t) :: {:ok, %__MODULE__{}} | {:error, String.t}
    def update_using_version(%{id: id, version: current_version_id, title: _title, body: _body, attachments: _attachments, tags: _tags, path: path} = version, global_id) when is_binary(id) and is_binary(current_version_id) and is_map(version) and is_binary(global_id) do
        new_version_id = Mongo.object_id() |> BSON.ObjectId.encode!()

        query = %{
            id: id,
            version: current_version_id,
            "access.#{global_id}.can_read": true,
            "access.#{global_id}.can_write": true
        }
        |> query_with_access(version, version |> Map.has_key?(:access), global_id)

        changeset = %{
            version: new_version_id,
            "versions.#{new_version_id}":
                version
                |> Map.delete(:id)
                |> Map.delete(:path)
                |> Map.delete(:access)
                |> Map.put(:created_by, global_id)
                |> Map.put(:created_at, DateTime.utc_now()),
            "access.#{global_id}.path": path,
            updated_at: DateTime.utc_now()
        }
        |> set_with_access(version, version |> Map.has_key?(:access), global_id)

        %{
            "$set": changeset
        }
        |> collection_update_manually(query)
        |> strip_privates
    end

    def current_version({:ok, models}, global_id) when is_list(models) and is_binary(global_id) do
        {:ok, (models |> Enum.map(fn model -> model |> current_version(global_id) end))}
    end

    def current_version({:ok, %__MODULE__{} = model}, global_id) when is_map(model) and is_binary(global_id) do
        case current_version(model, global_id) do
            nil -> {:error, nil}
            version -> {:ok, version}
        end
    end

    def current_version(%__MODULE__{id: id, version: version_id, versions: versions_map, access: access} = _model, global_id) when is_binary(version_id) and is_map(versions_map) and is_map(access) and is_binary(global_id) do
        versions_map
        |> Map.get(String.to_atom(version_id))
        |> Map.put(:version, version_id)
        |> Map.put(:path,
            access
            |> Map.get(String.to_atom(global_id))
            |> Map.get(:path)
                  )
        |> Map.put(:access,
            access
            |> Map.keys()
            |> Enum.map_reduce(%{}, fn access_key, merged_map ->
                {
                    access_key,
                    Map.merge(merged_map, %{
                        access_key =>
                            Map.get(access, access_key)
                            |> Map.delete(:path)
                            |> Map.put(:user,
                                # TODO: This is a bit hacky
                                # The notes collection should not be needing to access a different domain. However,
                                # in order to simplify requests for the clients, we perform the aggregation of user data
                                # in this place. Another, probably cleaner solution would be, to pass the pure result
                                # further up to an aggregation/breakdown service that takes care of this.
                                Paperwork.Internal.Request.user!(Atom.to_string(access_key))
                                |> Map.take(["email", "name"])
                            )
                    })
                }
            end)
            |> elem(1)
        )
        |> Map.put(:id, BSON.ObjectId.encode!(id)) #TODO: Fix this hack in a generic way
    end

    def current_version({:notfound, _} = model, global_id) when is_binary(global_id) do
        model
    end

    def steamroll_access(map) when is_map(map) do
        map
        |> Map.to_list()
        |> to_flat_map(%{})
    end

    defp to_flat_map([{pk, %{} = v} | t], acc) do
        v
        |> to_list(pk)
        |> to_flat_map(to_flat_map(t, acc))
    end

    defp to_flat_map([{k, v} | t], acc), do: to_flat_map(t, Map.put_new(acc, k, v))
    defp to_flat_map([], acc), do: acc

    defp to_list(map, pk) when is_atom(pk), do: to_list(map, Atom.to_string(pk))
    defp to_list(map, pk) when is_binary(pk), do: Enum.map(map, &update_key(pk, &1))

    defp update_key(pk, {k, v} = _val) when is_atom(k), do: update_key(pk, {Atom.to_string(k), v})
    defp update_key(pk, {k, v} = _val) when is_binary(k), do: {"#{pk}.#{k}", v}
end
