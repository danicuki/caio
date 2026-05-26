defmodule PortalWeb.PageControllerTest do
  use PortalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "The next job you'll actually want is in here somewhere."
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about")
    assert html_response(conn, 200) =~ "A quieter layer on top of the noisy job market."
  end

  test "GET /how-it-works", %{conn: conn} do
    conn = get(conn, ~p"/how-it-works")
    assert html_response(conn, 200) =~ "From public posting to usable job signal."
  end

  test "GET /pricing", %{conn: conn} do
    conn = get(conn, ~p"/pricing")
    assert html_response(conn, 200) =~ "Free while Caio is being built in public."
  end

  test "GET /privacy", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    assert html_response(conn, 200) =~ "Privacy policy"
  end

  test "GET /terms", %{conn: conn} do
    conn = get(conn, ~p"/terms")
    assert html_response(conn, 200) =~ "Terms of use"
  end

  test "GET /status", %{conn: conn} do
    conn = get(conn, ~p"/status")
    assert html_response(conn, 200) =~ "Crawler and search status"
  end

  test "GET /changelog redirects to GitHub commit history", %{conn: conn} do
    conn = get(conn, ~p"/changelog")
    assert redirected_to(conn, 302) == "https://github.com/danicuki/caio/commits/main"
  end
end
