defmodule PortalWeb.CompanyController do
  use PortalWeb, :controller

  alias Portal.Accounts
  alias Portal.Analytics
  alias Portal.Jobs

  def show(conn, %{"slug" => slug} = params) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    company = params["name"] || slug_to_name(slug)

    case Jobs.company_profile(company) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: PortalWeb.ErrorHTML)
        |> render(:"404")

      profile ->
        Analytics.capture("company_profile_viewed", analytics_id(conn, lead), %{
          company: profile.name,
          open_jobs_count: profile.stats.open_jobs_count
        })

        render(conn, :show,
          page_title: "#{profile.name} jobs",
          meta_description:
            "#{profile.stats.open_jobs_count} open #{profile.name} roles indexed by Caio, with source, location, and salary signals.",
          canonical_path: ~p"/companies/#{profile.slug}?name=#{profile.name}",
          analytics_distinct_id: analytics_id(conn, lead),
          profile: profile,
          lead: lead
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

  defp analytics_id(conn, nil), do: "session:#{get_session(conn, :session_token)}"
  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"

  defp slug_to_name(slug) do
    slug
    |> to_string()
    |> String.replace("-", " ")
  end
end
