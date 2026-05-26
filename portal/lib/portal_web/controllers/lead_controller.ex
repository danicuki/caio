defmodule PortalWeb.LeadController do
  use PortalWeb, :controller

  alias Portal.Analytics
  alias Portal.Accounts

  def create(conn, %{"lead" => lead_params}) do
    case Accounts.upsert_lead(lead_params) do
      {:ok, lead} ->
        conn =
          conn
          |> put_session(:lead_id, lead.id)
          |> ensure_session_token()

        Analytics.capture("lead_unlocked_search", analytics_id(conn, lead), %{
          return_to: lead_params["return_to"],
          has_linkedin_url: present?(lead_params["linkedin_url"]),
          has_target_role: present?(lead_params["target_role"]),
          has_target_location: present?(lead_params["target_location"]),
          consent_job_help: lead_params["consent_job_help"] == "true"
        })

        conn
        |> put_flash(:info, "Unlimited job search unlocked.")
        |> redirect(to: lead_params["return_to"] || ~p"/jobs")

      {:error, changeset} ->
        Analytics.capture("lead_unlock_failed", get_session(conn, :session_token), %{
          reason: "validation"
        })

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

  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"

  defp present?(value), do: is_binary(value) && String.trim(value) != ""

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
