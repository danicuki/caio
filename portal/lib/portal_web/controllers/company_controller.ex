defmodule PortalWeb.CompanyController do
  use PortalWeb, :controller

  alias Portal.Accounts
  alias Portal.Analytics
  alias Portal.Jobs

  def show(conn, %{"slug" => slug}) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)

    case Jobs.company_profile_by_slug(slug) do
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
          canonical_path: ~p"/companies/#{profile.slug}",
          json_ld: company_json_ld(profile),
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

  defp company_json_ld(profile) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => profile.name,
      "url" => PortalWeb.PageHTML.absolute_url("/companies/#{profile.slug}"),
      "logo" => profile.logo_url,
      "sameAs" => profile.website_url,
      "description" =>
        profile.description ||
          "#{profile.stats.open_jobs_count} open #{profile.name} jobs indexed by Caio."
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
