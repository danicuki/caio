defmodule PortalWeb.JobController do
  use PortalWeb, :controller

  alias Portal.Accounts
  alias Portal.Jobs

  def index(conn, params) do
    lead = current_lead(conn)
    unlocked? = not is_nil(lead)
    jobs = Jobs.search(params, unlocked?)
    total = Jobs.count(params)

    render(conn, :index,
      jobs: jobs,
      params: params,
      total: total,
      lead: lead,
      unlocked?: unlocked?,
      guest_limit: Jobs.guest_limit()
    )
  end

  def show(conn, %{"id" => id}) do
    job = Jobs.get!(id)

    render(conn, :show,
      job: job,
      company_stats: Jobs.company_stats(job),
      lead: current_lead(conn),
      session_token: session_token(conn)
    )
  end

  def apply(conn, %{"id" => id}) do
    job = Jobs.get!(id)
    lead = current_lead(conn)

    Accounts.record_interest(%{
      lead_id: lead && lead.id,
      job_post_id: job.id,
      session_token: session_token(conn),
      source_url: job.source_url
    })

    redirect(conn, external: job.source_url)
  end

  defp current_lead(conn), do: Accounts.get_lead(get_session(conn, :lead_id))

  defp session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> nil
      token -> token
    end
  end
end
