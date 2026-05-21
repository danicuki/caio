defmodule PortalWeb.PageController do
  use PortalWeb, :controller

  alias Portal.Jobs

  def home(conn, _params) do
    sample_jobs = Jobs.sample(6)
    total_jobs = Jobs.total_count()
    render(conn, :home, sample_jobs: sample_jobs, total_jobs: total_jobs)
  end
end
