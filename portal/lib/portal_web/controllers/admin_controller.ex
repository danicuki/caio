defmodule PortalWeb.AdminController do
  use PortalWeb, :controller

  alias Portal.CrawlerStats

  def index(conn, _params) do
    redirect(conn, to: ~p"/admin/leads")
  end

  def crawler(conn, _params) do
    render(conn, :crawler,
      page_title: "Crawler observability",
      meta_description: "Internal Caio crawler observability.",
      canonical_path: "/admin/crawler",
      stats: CrawlerStats.snapshot()
    )
  end
end
