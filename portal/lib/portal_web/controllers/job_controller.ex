defmodule PortalWeb.JobController do
  use PortalWeb, :controller

  alias Portal.Analytics
  alias Portal.Accounts
  alias Portal.Jobs

  def index(conn, params) do
    conn = ensure_session_token(conn)
    lead = current_lead(conn)
    unlocked? = not is_nil(lead)
    jobs = Jobs.search(params, unlocked?)
    total = Jobs.count(params)

    Analytics.capture("jobs_search_viewed", analytics_id(conn, lead), %{
      query: params["q"],
      role: params["role"],
      company: params["company"],
      location: params["location"],
      order: params["order"],
      result_count: total,
      unlocked: unlocked?
    })

    render(conn, :index,
      page_title: search_page_title(params),
      meta_description: search_meta_description(params, total),
      canonical_path: "/jobs",
      analytics_distinct_id: analytics_id(conn, lead),
      jobs: jobs,
      params: params,
      total: total,
      lead: lead,
      unlocked?: unlocked?,
      guest_limit: Jobs.guest_limit()
    )
  end

  def show(conn, %{"id" => id}) do
    conn = ensure_session_token(conn)
    job = Jobs.get!(id)
    lead = current_lead(conn)

    Analytics.capture("job_detail_viewed", analytics_id(conn, lead), %{
      job_id: job.id,
      source: job.source,
      company: job.company,
      has_salary: not is_nil(PortalWeb.JobHTML.salary(job))
    })

    render(conn, :show,
      page_title: job_page_title(job),
      meta_description: job_meta_description(job),
      canonical_path: ~p"/jobs/#{job.id}",
      og_type: "article",
      analytics_distinct_id: analytics_id(conn, lead),
      job: job,
      company_stats: Jobs.company_stats(job),
      lead: lead,
      session_token: session_token(conn)
    )
  end

  def apply(conn, %{"id" => id}) do
    job = Jobs.get!(id)
    apply_url = Jobs.apply_url(job)

    case lead_for_apply(conn, Map.get(conn.params, "lead", %{})) do
      {:ok, conn, lead} ->
        Accounts.record_interest(%{
          lead_id: lead.id,
          job_post_id: job.id,
          session_token: session_token(conn),
          source_url: apply_url
        })

        Analytics.capture("job_apply_clicked", analytics_id(conn, lead), %{
          job_id: job.id,
          source: job.source,
          company: job.company,
          has_session_lead: not is_nil(get_session(conn, :lead_id))
        })

        redirect(conn, external: apply_url)

      {:error, changeset} ->
        Analytics.capture("job_apply_lead_failed", session_token(conn), %{
          job_id: job.id,
          reason: "validation"
        })

        conn
        |> put_flash(:error, first_error(changeset))
        |> redirect(to: ~p"/jobs/#{job.id}")
    end
  end

  defp current_lead(conn), do: Accounts.get_lead(get_session(conn, :lead_id))

  defp lead_for_apply(conn, lead_params) do
    case current_lead(conn) do
      nil -> create_apply_lead(conn, lead_params)
      lead -> {:ok, ensure_session_token(conn), lead}
    end
  end

  defp create_apply_lead(conn, lead_params) do
    case Accounts.upsert_lead(lead_params) do
      {:ok, lead} ->
        conn =
          conn
          |> put_session(:lead_id, lead.id)
          |> ensure_session_token()

        {:ok, conn, lead}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> nil
      token -> token
    end
  end

  defp analytics_id(conn, nil), do: "session:#{get_session(conn, :session_token)}"
  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"

  defp search_page_title(params) do
    query = params["q"] || params["role"] || "Tech jobs"

    case params["location"] do
      nil -> "#{String.capitalize(query)}"
      "" -> "#{String.capitalize(query)}"
      location -> "#{String.capitalize(query)} jobs in #{location}"
    end
  end

  defp search_meta_description(params, total) do
    subject = params["q"] || params["role"] || "tech"
    location = params["location"] || "remote and global"

    "Search #{total} #{subject} jobs across #{location} on Caio, with cleaner salary, company, location, and source signals."
  end

  defp job_page_title(job), do: "#{job.title} at #{job.company || "a tech company"}"

  defp job_meta_description(job) do
    location = PortalWeb.JobHTML.compact_location(job)
    salary = PortalWeb.JobHTML.salary(job) || "salary not listed"

    "#{job.title} at #{job.company || "a tech company"} in #{location}. #{salary}. Open the original posting from Caio."
  end

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
