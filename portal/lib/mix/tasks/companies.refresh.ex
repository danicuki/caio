defmodule Mix.Tasks.Companies.Refresh do
  use Mix.Task

  @shortdoc "Rebuilds cached company profiles from job_posts"

  def run(_args) do
    Mix.Task.run("app.start")

    %{companies: companies} = Portal.Jobs.refresh_companies()

    Mix.shell().info("Refreshed #{companies} companies")
  end
end
