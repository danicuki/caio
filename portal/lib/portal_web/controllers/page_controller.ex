defmodule PortalWeb.PageController do
  use PortalWeb, :controller

  alias Portal.Jobs

  def home(conn, _params) do
    sample_jobs = Jobs.search(%{"order" => "random"}, false) |> Enum.take(6)
    render(conn, :home, sample_jobs: sample_jobs)
  end
end
