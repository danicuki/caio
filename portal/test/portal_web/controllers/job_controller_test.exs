defmodule PortalWeb.JobControllerTest do
  use PortalWeb.ConnCase

  import Ecto.Query

  alias Portal.Accounts
  alias Portal.Accounts.JobInterest
  alias Portal.Jobs
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
    job = job_fixture(%{remote: 1})

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ ~s(<script type="application/ld+json">)
    assert response =~ ~s("JobPosting")
    assert response =~ ~s("datePosted")
    assert response =~ ~s("validThrough")
    assert response =~ ~s("jobLocationType":"TELECOMMUTE")
    assert response =~ ~s("applicantLocationRequirements")
    assert response =~ "Senior Elixir Engineer"
    assert response =~ "Caio Labs"
  end

  test "GET /jobs/:id falls back to created_at for JobPosting datePosted", %{conn: conn} do
    job =
      job_fixture(%{
        published_at: nil,
        created_at: "2026-05-15T12:00:00Z",
        location_country: "US"
      })

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    assert response =~ ~s("datePosted":"2026-05-15")
    assert response =~ ~s("validThrough":"2026-08-13T23:59:59Z")
    assert response =~ ~s("jobLocation")
    assert response =~ ~s("addressCountry":"US")
  end

  test "GET /jobs/:id omits JobPosting structured data without a usable location", %{conn: conn} do
    job =
      job_fixture(%{
        location: "",
        remote: 0,
        location_scope: nil,
        location_city: nil,
        location_country: nil
      })

    conn = get(conn, ~p"/jobs/#{job.id}")
    response = html_response(conn, 200)

    refute response =~ ~s("JobPosting")
    refute response =~ ~s("datePosted")
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

  test "GET /jobs orders newest results by published date", %{conn: conn} do
    older =
      job_fixture(%{
        title: "Older Backend Engineer",
        published_at: "2026-05-01",
        created_at: "2026-06-01T12:00:00Z"
      })

    newer =
      job_fixture(%{
        title: "Newer Backend Engineer",
        published_at: "2026-06-01",
        created_at: "2026-05-01T12:00:00Z"
      })

    conn = get(conn, ~p"/jobs?order=recent")
    response = html_response(conn, 200)

    assert response =~ newer.title
    assert response =~ older.title
    assert String.split(response, newer.title, parts: 2) |> List.last() =~ older.title
  end

  test "GET /jobs renders prototype chips as real filter links", %{conn: conn} do
    conn = get(conn, ~p"/jobs")
    response = html_response(conn, 200)

    assert response =~ ~s(href="/jobs?workplace=remote")
    assert response =~ ~s(href="/jobs?seniority=senior")
    assert response =~ ~s(href="/jobs?salary=listed")
    assert response =~ ~s(href="/jobs?role=engineer")
  end

  test "GET /jobs supports quick filter params", %{conn: conn} do
    job_fixture(%{title: "Senior Backend Engineer", remote: 1, salary: "$100k"})

    for path <- [
          ~p"/jobs?seniority=senior",
          ~p"/jobs?workplace=remote",
          ~p"/jobs?salary=listed",
          ~p"/jobs?perk=visa"
        ] do
      conn = get(conn, path)
      assert html_response(conn, 200) =~ "Best matches"
    end
  end

  test "GET /jobs redirects unlocked oversized pages before loading results", %{conn: conn} do
    job_fixture()
    {:ok, lead} = Accounts.upsert_lead(%{"email" => "member@example.com"})

    conn =
      conn
      |> init_test_session(lead_id: lead.id)
      |> get(~p"/jobs?page=10000")

    assert redirected_to(conn, 302) == "/jobs?page=1"
  end

  test "max page respects the public browse cap for capped counts" do
    assert Jobs.max_page("10000+", 50) == 200
    assert Jobs.max_page(0, 50) == 1
    assert Jobs.max_page(51, 50) == 2
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

    assert response =~ ~s(<meta name="robots" content="noindex,follow")
    assert response =~ "Search"
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
