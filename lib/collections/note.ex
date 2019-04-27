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
                can_leave: Boolean.t()
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

    @spec list(global_id :: String.t) :: {:ok, [%__MODULE__{}]} | {:notfound, nil}
    def list(global_id) when is_binary(global_id) do
        %{
            "access.#{global_id}.can_read": true
        }
        |> collection_find(true)
        |> strip_privates
    end

    @spec create_using_version(version :: Map.t, global_id :: String.t) :: {:ok, %__MODULE__{}} | {:error, String.t}
    def create_using_version(%{title: _title, body: _body, attachments: _attachments, tags: _tags, path: path} = version, global_id) when is_map(version) and is_binary(global_id) do
        version_id = UUID.uuid4()

        %__MODULE__{
            version: version_id,
            versions: %{
                String.to_atom(version_id) => version
                                              |> Map.delete(:path)
                                              |> Map.put(:created_by, global_id)
                                              |> Map.put(:created_at, DateTime.utc_now())
            },
            access: %{
                String.to_atom(global_id) => %{
                    path: path,
                    can_read: true,
                    can_write: true,
                    can_share: true,
                    can_leave: false
                }
            },
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now(),
            deleted_at: nil
        }
        |> collection_insert
        |> strip_privates
    end

    @spec update_using_version(version :: Map.t, global_id :: String.t) :: {:ok, %__MODULE__{}} | {:error, String.t}
    def update_using_version(%{id: id, title: _title, body: _body, attachments: _attachments, tags: _tags, path: path} = version, global_id) when is_binary(id) and is_map(version) and is_binary(global_id) do
        version_id = UUID.uuid4()

        query = %{
            id: id,
            "access.#{global_id}.can_read": true,
            "access.#{global_id}.can_write": true
        }

        %{
            "$set": %{
                version: version_id,
                "versions.#{version_id}": version
                                          |> Map.delete(:id)
                                          |> Map.delete(:path)
                                          |> Map.put(:created_by, global_id)
                                          |> Map.put(:created_at, DateTime.utc_now()),
                "access.#{global_id}.path": path,
                updated_at: DateTime.utc_now(),
            }
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
        |> Map.put(:path, access
                          |> Map.get(String.to_atom(global_id))
                          |> Map.get(:path)
                  )
        |> Map.put(:id, BSON.ObjectId.encode!(id)) #TODO: Fix this hack in a generic way
    end

    def current_version({:notfound, _} = model, global_id) when is_binary(global_id) do
        model
    end
end
