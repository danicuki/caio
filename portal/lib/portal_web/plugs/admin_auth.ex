defmodule PortalWeb.Plugs.AdminAuth do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:portal, :admin, [])
    username = Keyword.get(config, :username)
    password = Keyword.get(config, :password)

    if configured?(username, password) do
      conn
      |> put_resp_header("x-robots-tag", "noindex, nofollow")
      |> Plug.BasicAuth.basic_auth(username: username, password: password)
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(503, "Admin is not configured. Set ADMIN_USERNAME and ADMIN_PASSWORD.")
      |> halt()
    end
  end

  defp configured?(username, password) do
    is_binary(username) and String.trim(username) != "" and
      is_binary(password) and String.trim(password) != ""
  end
end
