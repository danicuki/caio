defmodule PortalWeb.LeadControllerTest do
  use PortalWeb.ConnCase

  alias Portal.Accounts

  test "POST /logout clears lead session", %{conn: conn} do
    {:ok, lead} = Accounts.upsert_lead(%{"email" => "member@example.com"})

    conn =
      conn
      |> init_test_session(lead_id: lead.id, session_token: "session-token")
      |> post(~p"/logout")

    assert redirected_to(conn, 302) == ~p"/jobs"
    refute get_session(conn, :lead_id)
    refute get_session(conn, :session_token)
  end
end
