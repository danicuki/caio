defmodule PortalWeb.AdminController do
  use PortalWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/admin/leads")
  end
end
