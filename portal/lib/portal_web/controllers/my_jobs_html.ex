defmodule PortalWeb.MyJobsHTML do
  use PortalWeb, :html

  embed_templates "my_jobs_html/*"

  def format_interest_date(nil), do: "Opened recently"

  def format_interest_date(datetime) do
    date = DateTime.to_date(datetime)

    case Date.diff(Date.utc_today(), date) do
      days when days <= 0 -> "Opened today"
      1 -> "Opened yesterday"
      days when days < 30 -> "Opened #{days}d ago"
      days -> "Opened #{div(days, 30)}mo ago"
    end
  end
end
