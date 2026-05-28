defmodule PortalWeb.JobControllerTest do
  use PortalWeb.ConnCase

  import Ecto.Query

  alias Portal.Accounts
  alias Portal.Accounts.JobInterest
  alias Portal.Jobs.JobPost
  alias Portal.Repo

  test "GET /jobs renders unlock as a modal instead of an inline form", %{conn: conn} do
    conn = get(conn, ~p"/jobs")
    response = html_response(conn, 200)

    assert response =~ "id=\"unlock\""
    assert response =~ "class=\"profile-modal\""
    assert response =~ "More matching jobs"
    assert response =~ "Continue with GitHub"
    refute response =~ "Continue with Google"
  end

  test "GET /jobs/:id asks guests for email before applying", %{conn: conn} do
    job = job_fixture()

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ "id=\"apply-profile\""
    assert response =~ "class=\"profile-modal\""
    assert response =~ "name=\"lead[email]\""
    assert response =~ "Senior Elixir Engineer at Caio Labs"
    assert response =~ "/auth/github?apply_job_id=#{job.id}"
    assert response =~ "Continue to application"
    refute response =~ "Continue with Google"
  end

  test "GET /jobs/:id includes JobPosting structured data", %{conn: conn} do
    job = job_fixture()

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ ~s(<script type="application/ld+json">)
    assert response =~ ~s("JobPosting")
    assert response =~ "Senior Elixir Engineer"
    assert response =~ "Caio Labs"
  end

  test "GET /jobs/:id preserves structured job description HTML", %{conn: conn} do
    job =
      job_fixture(%{
        description:
          "<p><strong>Intro</strong></p><h2>Aufgaben</h2><ul><li>Plan systems</li><li>Coordinate teams</li></ul>"
      })

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ "<h2>Aufgaben</h2>"
    assert response =~ "<ul><li>Plan systems</li><li>Coordinate teams</li></ul>"
    refute response =~ "Intro Aufgaben Plan systems Coordinate teams"
  end

  test "GET /jobs renders structured source tags as readable labels", %{conn: conn} do
    job_fixture(%{
      tags_json:
        Jason.encode!([
          %{"name" => "Fortune 1000", "short_name" => "fortune-1000-companies"},
          %{"short_name" => "remote-first"}
        ])
    })

    conn = get(conn, ~p"/jobs?order=random")
    response = html_response(conn, 200)

    assert response =~ "Fortune 1000"
    assert response =~ "remote first"
    refute response =~ "Protocol.UndefinedError"
  end

  test "GET /jobs hides obvious non-tech engineering roles", %{conn: conn} do
    job_fixture(%{
      title: "Mechanical Engineer",
      category: "Mechanical Engineering",
      tags_json: Jason.encode!(["Mechanical Or Industrial Engineering"])
    })

    job_fixture(%{
      title: "Backend Engineer",
      category: "Software Engineering",
      tags_json: Jason.encode!(["Ruby", "Postgres"])
    })

    conn = get(conn, ~p"/jobs?order=random")
    response = html_response(conn, 200)

    assert response =~ "Backend Engineer"
    refute response =~ "Mechanical Engineer"
    refute response =~ "Mechanical Or Industrial Engineering"
  end

  test "GET /jobs hides restaurant delivery roles", %{conn: conn} do
    job_fixture(%{
      title: "Delivery Driver",
      company: "DominoS",
      category: "General Business",
      tags_json: Jason.encode!(["Restaurants"])
    })

    job_fixture(%{
      title: "Software Engineer",
      company: "Canva",
      category: "Software Engineering",
      tags_json: Jason.encode!(["Frontend"])
    })

    conn = get(conn, ~p"/jobs?order=random")
    response = html_response(conn, 200)

    assert response =~ "Software Engineer"
    refute response =~ "Delivery Driver"
    refute response =~ "DominoS"
  end

  test "GET /jobs uses search params in title description and canonical", %{conn: conn} do
    job_fixture(%{
      title: "Docker Engineer",
      category: "Platform",
      location: "Lisbon",
      location_city: "Lisbon",
      description: "Build Docker infrastructure."
    })

    conn = get(conn, ~p"/jobs?q=docker&location=Lisbon&order=random")
    response = html_response(conn, 200)

    assert response =~ "<title"
    assert response =~ "Docker jobs in Lisbon · Caio"

    assert response =~
             ~s(<link rel="canonical" href="https://caio-jobs.com/jobs?q=docker&amp;location=Lisbon")

    assert response =~ "Meet"
    assert response =~ "docker jobs in Lisbon"
    assert response =~ ~s("SearchResultsPage")
  end

  test "GET /jobs/:id formats plain descriptions with common job headings", %{conn: conn} do
    job =
      job_fixture(%{
        description:
          "Who we are About Stripe Stripe is a financial infrastructure platform. About the team The policy team works globally. What you’ll do Support public affairs campaigns. Responsibilities Coordinate launches. Minimum requirements Minimum 3+ years of experience. Preferred qualifications Policy ecosystem relationships."
      })

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ "<h3>Who we are</h3>"
    assert response =~ "<h3>About the team</h3>"
    assert response =~ "<h3>What you’ll do</h3>"
    assert response =~ "<h3>Responsibilities</h3>"
    assert response =~ "<h3>Minimum requirements</h3>"
    assert response =~ "<h3>Preferred qualifications</h3>"
  end

  test "GET /jobs/:id formats Himalayas-style plain descriptions without punctuation before headings",
       %{conn: conn} do
    job =
      job_fixture(%{
        description:
          "Canonical builds Ubuntu for the world The role entails Management of a professional support team Operational control and accountability What are we looking for in you Extensive CLI experience with Linux What we offer colleagues Distributed work environment About Canonical Canonical is a pioneering tech firm Canonical is an equal opportunity employer We foster a workplace free from discrimination."
      })

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ "<h3>The role entails</h3>"
    assert response =~ "<h3>What are we looking for in you</h3>"
    assert response =~ "<h3>What we offer colleagues</h3>"
    assert response =~ "<h3>About Canonical</h3>"
    assert response =~ "<h3>Canonical is an equal opportunity employer</h3>"
  end

  test "POST /jobs/:id/apply creates a lead for guest applicants", %{conn: conn} do
    job = job_fixture()

    conn =
      post(conn, ~p"/jobs/#{job.id}/apply", %{
        "lead" => %{"email" => "Applicant@Example.COM"}
      })

    assert redirected_to(conn, 302) == job.source_url

    lead = Repo.get_by!(Accounts.Lead, email: "applicant@example.com")
    assert get_session(conn, :lead_id) == lead.id
    assert get_session(conn, :session_token)

    interest = Repo.one!(from(i in JobInterest, where: i.job_post_id == ^job.id))
    assert interest.lead_id == lead.id
    assert interest.source_url == job.source_url
  end

  test "POST /jobs/:id/apply uses the existing lead session", %{conn: conn} do
    job = job_fixture()
    {:ok, lead} = Accounts.upsert_lead(%{"email" => "member@example.com"})

    conn =
      conn
      |> init_test_session(lead_id: lead.id)
      |> post(~p"/jobs/#{job.id}/apply")

    assert redirected_to(conn, 302) == job.source_url
    assert get_session(conn, :lead_id) == lead.id
    assert get_session(conn, :session_token)

    interest = Repo.one!(from(i in JobInterest, where: i.job_post_id == ^job.id))
    assert interest.lead_id == lead.id
  end

  test "POST /jobs/:id/apply redirects to an apply URL override when present", %{conn: conn} do
    job =
      job_fixture(%{
        source: "linkedin",
        source_key: "4390863705",
        source_url: "https://www.linkedin.com/jobs/view/4390863705"
      })

    {:ok, lead} = Accounts.upsert_lead(%{"email" => "member@example.com"})

    conn =
      conn
      |> init_test_session(lead_id: lead.id)
      |> post(~p"/jobs/#{job.id}/apply")

    assert redirected_to(conn, 302) ==
             "https://careers.terracon.com/job/midvale/supervisor-project-coordination/37184/85966092016"

    interest = Repo.one!(from(i in JobInterest, where: i.job_post_id == ^job.id))

    assert interest.source_url ==
             "https://careers.terracon.com/job/midvale/supervisor-project-coordination/37184/85966092016"
  end

  defp job_fixture(attrs \\ %{}) do
    Repo.insert!(
      %JobPost{
        source: "test",
        source_key: "test-#{System.unique_integer([:positive])}",
        title: "Senior Elixir Engineer",
        company: "Caio Labs",
        location: "Remote",
        source_url: "https://example.com/apply/#{System.unique_integer([:positive])}",
        published_at: Date.utc_today() |> Date.to_iso8601(),
        description: "Build useful job search software.",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      |> Map.merge(attrs)
    )
  end
end
