defmodule PortalWeb.AuthController do
  use PortalWeb, :controller

  alias Portal.Analytics
  alias Portal.Accounts
  alias Portal.GitHubOAuth
  alias Portal.Jobs

  def github(conn, params) do
    if GitHubOAuth.configured?() do
      conn = ensure_session_token(conn)
      state = Ecto.UUID.generate()
      return_to = safe_return_to(params["return_to"])
      apply_job_id = params["apply_job_id"]

      Analytics.capture("github_login_started", "session:#{get_session(conn, :session_token)}", %{
        return_to: return_to,
        apply_job_id: apply_job_id
      })

      conn
      |> put_session(:github_oauth_state, state)
      |> put_session(:github_return_to, return_to)
      |> put_session(:github_apply_job_id, apply_job_id)
      |> redirect(external: github_authorize_url(conn, state))
    else
      Analytics.capture("github_login_not_configured", get_session(conn, :session_token), %{})

      conn
      |> put_flash(:error, "GitHub login is not configured yet.")
      |> redirect(to: safe_return_to(params["return_to"]))
    end
  end

  def github_callback(conn, %{"code" => code, "state" => state}) do
    with true <- valid_state?(conn, state),
         {:ok, profile} <- GitHubOAuth.exchange_code(code, github_redirect_uri(conn)),
         {:ok, lead} <- Accounts.upsert_lead(%{"email" => profile.email}) do
      conn =
        conn
        |> delete_session(:github_oauth_state)
        |> put_session(:lead_id, lead.id)
        |> ensure_session_token()

      Analytics.capture("github_login_completed", analytics_id(conn, lead), %{
        has_apply_job_id: present?(get_session(conn, :github_apply_job_id))
      })

      continue_after_github(conn, lead)
    else
      false ->
        Analytics.capture("github_login_failed", get_session(conn, :session_token), %{
          reason: "state"
        })

        github_error(conn, "GitHub login expired. Please try again.")

      {:error, message} when is_binary(message) ->
        Analytics.capture("github_login_failed", get_session(conn, :session_token), %{
          reason: message
        })

        github_error(conn, message)

      {:error, changeset} ->
        Analytics.capture("github_login_failed", get_session(conn, :session_token), %{
          reason: "lead_validation"
        })

        github_error(conn, first_error(changeset))
    end
  end

  def github_callback(conn, _params) do
    github_error(conn, "GitHub did not authorize the login.")
  end

  defp github_authorize_url(conn, state) do
    query =
      URI.encode_query(%{
        "client_id" => GitHubOAuth.client_id(),
        "redirect_uri" => github_redirect_uri(conn),
        "scope" => "user:email",
        "state" => state
      })

    "https://github.com/login/oauth/authorize?#{query}"
  end

  defp github_redirect_uri(conn) do
    System.get_env("GITHUB_REDIRECT_URI") || url(conn, ~p"/auth/github/callback")
  end

  defp continue_after_github(conn, lead) do
    case get_session(conn, :github_apply_job_id) do
      nil ->
        conn
        |> delete_session(:github_return_to)
        |> put_flash(:info, "Signed in with GitHub.")
        |> redirect(to: get_session(conn, :github_return_to) || ~p"/jobs")

      "" ->
        conn
        |> delete_session(:github_return_to)
        |> delete_session(:github_apply_job_id)
        |> put_flash(:info, "Signed in with GitHub.")
        |> redirect(to: get_session(conn, :github_return_to) || ~p"/jobs")

      job_id ->
        apply_after_github(conn, lead, job_id)
    end
  end

  defp apply_after_github(conn, lead, job_id) do
    job = Jobs.get!(job_id)
    apply_url = Jobs.apply_url(job)

    Accounts.record_interest(%{
      lead_id: lead.id,
      job_post_id: job.id,
      session_token: get_session(conn, :session_token),
      source_url: apply_url
    })

    Analytics.capture("job_apply_clicked", analytics_id(conn, lead), %{
      job_id: job.id,
      source: job.source,
      company: job.company,
      via_github: true
    })

    conn
    |> delete_session(:github_return_to)
    |> delete_session(:github_apply_job_id)
    |> redirect(external: apply_url)
  end

  defp github_error(conn, message) do
    return_to = get_session(conn, :github_return_to) || ~p"/jobs"

    conn
    |> delete_session(:github_oauth_state)
    |> delete_session(:github_return_to)
    |> delete_session(:github_apply_job_id)
    |> put_flash(:error, message)
    |> redirect(to: return_to)
  end

  defp valid_state?(conn, state) do
    is_binary(state) and state == get_session(conn, :github_oauth_state)
  end

  defp safe_return_to(nil), do: ~p"/jobs"
  defp safe_return_to(""), do: ~p"/jobs"
  defp safe_return_to("//" <> _), do: ~p"/jobs"
  defp safe_return_to("/" <> _ = path), do: path
  defp safe_return_to(_), do: ~p"/jobs"

  defp ensure_session_token(conn) do
    case get_session(conn, :session_token) do
      nil -> put_session(conn, :session_token, Ecto.UUID.generate())
      _ -> conn
    end
  end

  defp analytics_id(conn, lead), do: "lead:#{lead.id}:#{get_session(conn, :session_token)}"

  defp present?(value), do: is_binary(value) && String.trim(value) != ""

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
