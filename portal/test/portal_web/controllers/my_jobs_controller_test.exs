defmodule PortalWeb.MyJobsControllerTest do
  use PortalWeb.ConnCase

  alias Portal.Accounts
  alias Portal.Jobs.JobPost
  alias Portal.Repo

  test "GET /my-jobs redirects guests to search", %{conn: conn} do
    conn = get(conn, ~p"/my-jobs")

    assert redirected_to(conn) == ~p"/jobs"
  end

  test "GET /my-jobs renders the lead's opened jobs", %{conn: conn} do
    {:ok, lead} = Accounts.upsert_lead(%{"email" => "member@example.com"})
    job = job_fixture("Senior Elixir Engineer")
    other_job = job_fixture("Other Person Role")

    Accounts.record_interest(%{
      lead_id: lead.id,
      job_post_id: job.id,
      source_url: job.source_url,
      session_token: "session-1"
    })

    Accounts.record_interest(%{
      lead_id: nil,
      job_post_id: other_job.id,
      source_url: other_job.source_url,
      session_token: "session-2"
    })

    conn =
      conn
      |> init_test_session(lead_id: lead.id)
      |> get(~p"/my-jobs")

    response = html_response(conn, 200)

    assert response =~ "Jobs you opened through Caio"
    assert response =~ "Senior Elixir Engineer"
    refute response =~ "Other Person Role"
    assert response =~ "Open source"
  end

  defp job_fixture(title) do
    Repo.insert!(%JobPost{
      source: "test",
      source_key: "test-#{System.unique_integer([:positive])}",
      title: title,
      company: "Caio Labs",
      location: "Remote",
      source_url: "https://example.com/apply/#{System.unique_integer([:positive])}",
      published_at: Date.utc_today() |> Date.to_iso8601(),
      description: "Build useful job search software.",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
