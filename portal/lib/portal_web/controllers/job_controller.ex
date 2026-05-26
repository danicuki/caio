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

    case lead_for_apply(conn, Map.get(conn.params, "lead", %{})) do
      {:ok, conn, lead} ->
        Accounts.record_interest(%{
          lead_id: lead.id,
          job_post_id: job.id,
          session_token: session_token(conn),
          source_url: job.source_url
        })

        redirect(conn, external: job.source_url)

      {:error, changeset} ->
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

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
