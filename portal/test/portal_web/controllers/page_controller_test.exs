defmodule PortalWeb.PageControllerTest do
  use PortalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "The next job you'll actually want is in here somewhere."
    assert response =~ ~s(<meta property="og:title")
    assert response =~ "caio-social-preview.png"
    assert response =~ ~s(<link rel="canonical" href="https://caio-jobs.com/")
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about")
    assert html_response(conn, 200) =~ "A quieter layer on top of the noisy job market."
  end

  test "GET /how-it-works", %{conn: conn} do
    conn = get(conn, ~p"/how-it-works")
    assert html_response(conn, 200) =~ "From public posting to usable job signal."
  end

  test "GET /pricing", %{conn: conn} do
    conn = get(conn, ~p"/pricing")
    response = html_response(conn, 200)
    assert response =~ "Free while Caio is being built in public."
    assert response =~ "https://github.com/danicuki/caio"
  end

  test "GET /privacy", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    response = html_response(conn, 200)

    assert response =~ "Privacy policy"
    assert response =~ "Session replay may be enabled"
  end

  test "GET /terms", %{conn: conn} do
    conn = get(conn, ~p"/terms")
    assert html_response(conn, 200) =~ "Terms of use"
  end

  test "GET /status", %{conn: conn} do
    conn = get(conn, ~p"/status")
    assert html_response(conn, 200) =~ "Crawler and search status"
  end

  test "GET /changelog redirects to GitHub commit history", %{conn: conn} do
    conn = get(conn, ~p"/changelog")
    assert redirected_to(conn, 302) == "https://github.com/danicuki/caio/commits/main"
  end

  test "GET /robots.txt exposes the sitemap", %{conn: conn} do
    conn = get(conn, "/robots.txt")
    assert text_response(conn, 200) =~ "Sitemap: https://caio-jobs.com/sitemap.xml"
  end

  test "GET /sitemap.xml lists core launch pages", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    response = response(conn, 200)

    assert response =~ "https://caio-jobs.com/sitemap-static.xml"
    assert response =~ "https://caio-jobs.com/sitemap-companies.xml"
    assert response =~ "https://caio-jobs.com/sitemap-locations.xml"
    assert response =~ "https://caio-jobs.com/sitemap-keywords.xml"
  end

  test "GET /sitemap-static.xml lists core launch pages", %{conn: conn} do
    conn = get(conn, "/sitemap-static.xml")
    response = response(conn, 200)

    assert response =~ "https://caio-jobs.com/"
    assert response =~ "https://caio-jobs.com/jobs"
    assert response =~ "https://caio-jobs.com/privacy"
  end

  test "GET /sitemap-companies.xml lists company pages", %{conn: conn} do
    insert_company_job("Caio Labs")

    conn = get(conn, "/sitemap-companies.xml")
    response = response(conn, 200)

    assert response =~ "https://caio-jobs.com/companies/caio-labs"
    refute response =~ "?name="
  end

  test "GET /sitemap-locations.xml lists city search pages", %{conn: conn} do
    insert_company_job("Caio Labs", %{location_city: "Lisbon"})
    insert_company_job("Caio Tools", %{location_city: "Lisbon"})

    conn = get(conn, "/sitemap-locations.xml")
    response = response(conn, 200)

    assert response =~ "https://caio-jobs.com/jobs?location=Lisbon"
  end

  test "GET /sitemap-keywords.xml lists keyword search pages", %{conn: conn} do
    insert_company_job("Caio Labs", %{category: "Docker"})
    insert_company_job("Caio Tools", %{category: "Docker"})
    insert_company_job("Caio Systems", %{category: "Docker"})

    conn = get(conn, "/sitemap-keywords.xml")
    response = response(conn, 200)

    assert response =~ "https://caio-jobs.com/jobs?q=Docker"
  end

  defp insert_company_job(company, attrs \\ %{}) do
    Portal.Repo.insert!(
      %Portal.Jobs.JobPost{
        source: "test",
        source_key: "test-#{System.unique_integer([:positive])}",
        title: "Senior Engineer",
        company: company,
        location: "Remote",
        source_url: "https://example.com/#{System.unique_integer([:positive])}",
        published_at: Date.utc_today() |> Date.to_iso8601(),
        description: "Build useful software.",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      |> Map.merge(attrs)
    )
  end
end
