defmodule PortalWeb.MyJobsController do
  use PortalWeb, :controller

  alias Portal.Accounts
  alias Portal.Analytics

  def index(conn, _params) do
    conn = ensure_session_token(conn)

    case current_lead(conn) do
      nil ->
        conn
        |> put_flash(:info, "Create a free profile to keep track of jobs you open.")
        |> redirect(to: ~p"/jobs")

      lead ->
        interests = Accounts.recent_interests(lead.id)

        Analytics.capture("my_jobs_viewed", analytics_id(conn, lead), %{
          interest_count: length(interests)
        })

        render(conn, :index,
          page_title: "My jobs",
          meta_description:
            "Your Caio job tray: roles you opened, companies you checked, and source links you can revisit.",
          canonical_path: ~p"/my-jobs",
          analytics_distinct_id: analytics_id(conn, lead),
          lead: lead,
          interests: interests
        )
    end
  end

  defp current_lead(conn), do: Accounts.get_lead(get_session(conn, :lead_id))

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"
end
