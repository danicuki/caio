defmodule PortalWeb.AuthController do
  use PortalWeb, :controller

  alias Portal.Accounts
  alias Portal.GitHubOAuth
  alias Portal.Jobs

  def github(conn, params) do
    if GitHubOAuth.configured?() do
      state = Ecto.UUID.generate()
      return_to = safe_return_to(params["return_to"])
      apply_job_id = params["apply_job_id"]

      conn
      |> put_session(:github_oauth_state, state)
      |> put_session(:github_return_to, return_to)
      |> put_session(:github_apply_job_id, apply_job_id)
      |> redirect(external: github_authorize_url(conn, state))
    else
      conn
      |> put_flash(:error, "GitHub login is not configured yet.")
      |> redirect(to: safe_return_to(params["return_to"]))
    end
  end

  def github_callback(conn, %{"code" => code, "state" => state}) do
    with true <- valid_state?(conn, state),
         {:ok, profile} <- GitHubOAuth.exchange_code(code, github_redirect_uri(conn)),
         {:ok, lead} <- Accounts.upsert_lead(%{"email" => profile.email}) do
      conn
      |> delete_session(:github_oauth_state)
      |> put_session(:lead_id, lead.id)
      |> ensure_session_token()
      |> continue_after_github(lead)
    else
      false ->
        github_error(conn, "GitHub login expired. Please try again.")

      {:error, message} when is_binary(message) ->
        github_error(conn, message)

      {:error, changeset} ->
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

    Accounts.record_interest(%{
      lead_id: lead.id,
      job_post_id: job.id,
      session_token: get_session(conn, :session_token),
      source_url: job.source_url
    })

    conn
    |> delete_session(:github_return_to)
    |> delete_session(:github_apply_job_id)
    |> redirect(external: job.source_url)
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

  defp first_error(changeset) do
    {field, {message, _}} = List.first(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end
end
