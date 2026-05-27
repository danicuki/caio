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
