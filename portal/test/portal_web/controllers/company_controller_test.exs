defmodule PortalWeb.CompanyControllerTest do
  use PortalWeb.ConnCase

  alias Portal.Jobs.JobPost
  alias Portal.Repo

  test "GET /companies/:slug renders a generated company profile", %{conn: conn} do
    insert_job("Caio Labs", "Senior Elixir Engineer", "Remote", "test")
    insert_job("Caio Labs", "Product Engineer", "Brazil", "arbeitnow")
    insert_job("Other Company", "Backend Engineer", "Remote", "test")
    Portal.Jobs.refresh_companies()

    conn = get(conn, ~p"/companies/caio-labs")
    response = html_response(conn, 200)

    assert response =~ "Caio Labs jobs on Caio"
    assert response =~ "Senior Elixir Engineer"
    assert response =~ "Product Engineer"
    refute response =~ "Other Company"
    assert response =~ "Open roles"
    assert response =~ "Sources"
    assert response =~ ~s("Organization")
    assert response =~ "https://caio-jobs.com/companies/caio-labs"
  end

  test "GET /companies/:slug returns 404 for unknown company", %{conn: conn} do
    conn = get(conn, ~p"/companies/not-real")

    assert html_response(conn, 404)
  end

  defp insert_job(company, title, location, source) do
    Repo.insert!(%JobPost{
      source: source,
      source_key: "#{source}-#{System.unique_integer([:positive])}",
      title: title,
      company: company,
      location: location,
      source_url: "https://example.com/#{System.unique_integer([:positive])}",
      published_at: Date.utc_today() |> Date.to_iso8601(),
      description: "Build useful software.",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
