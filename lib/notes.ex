defmodule Paperwork.Notes do
  use Paperwork.Server
  use Paperwork.Helpers.Response

  pipeline do
    plug Paperwork.Auth.Plug.SessionLoader
  end

  namespace :notes do
    get do
      conn
      |> resp({:ok, %{}})
    end
  end
end
