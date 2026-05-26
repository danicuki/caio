defmodule PortalWeb.LeadController do
  use PortalWeb, :controller

  alias Portal.Accounts

  def create(conn, %{"lead" => lead_params}) do
    case Accounts.upsert_lead(lead_params) do
      {:ok, lead} ->
        conn
        |> put_session(:lead_id, lead.id)
        |> ensure_session_token()
        |> put_flash(:info, "Unlimited job search unlocked.")
        |> redirect(to: lead_params["return_to"] || ~p"/jobs")

      {:error, changeset} ->
        conn
        |> put_flash(:error, first_error(changeset))
        |> redirect(to: lead_params["return_to"] || ~p"/jobs")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> configure_session(renew: true)
    |> put_flash(:info, "You are logged out.")
    |> redirect(to: ~p"/jobs")
  end

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
