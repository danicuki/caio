defmodule PortalWeb.AuthControllerTest do
  use PortalWeb.ConnCase

  setup do
    original_client_id = System.get_env("GITHUB_CLIENT_ID")
    original_client_secret = System.get_env("GITHUB_CLIENT_SECRET")
    original_redirect_uri = System.get_env("GITHUB_REDIRECT_URI")

    on_exit(fn ->
      restore_env("GITHUB_CLIENT_ID", original_client_id)
      restore_env("GITHUB_CLIENT_SECRET", original_client_secret)
      restore_env("GITHUB_REDIRECT_URI", original_redirect_uri)
    end)

    :ok
  end

  test "GET /auth/github redirects to GitHub when configured", %{conn: conn} do
    System.put_env("GITHUB_CLIENT_ID", "test-client-id")
    System.put_env("GITHUB_CLIENT_SECRET", "test-client-secret")
    System.put_env("GITHUB_REDIRECT_URI", "http://localhost:4000/auth/github/callback")

    conn = get(conn, ~p"/auth/github?return_to=/jobs&apply_job_id=123")
    location = redirected_to(conn, 302)

    assert String.starts_with?(location, "https://github.com/login/oauth/authorize?")
    assert location =~ "client_id=test-client-id"
    assert location =~ "scope=user%3Aemail"
    refute location =~ "test-client-secret"
    assert get_session(conn, :github_oauth_state)
    assert get_session(conn, :github_return_to) == "/jobs"
    assert get_session(conn, :github_apply_job_id) == "123"
  end

  test "GET /auth/github redirects back when missing env config", %{conn: conn} do
    System.delete_env("GITHUB_CLIENT_ID")
    System.delete_env("GITHUB_CLIENT_SECRET")

    conn = get(conn, ~p"/auth/github?return_to=/pricing")

    assert redirected_to(conn, 302) == ~p"/pricing"
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
