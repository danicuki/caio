defmodule Mix.Tasks.Companies.RefreshLogos do
  use Mix.Task

  @shortdoc "Caches company logo URLs from known company domains"

  def run(args) do
    Mix.Task.run("app.start")

    opts = parse_args(args)
    %{companies: companies} = Portal.Jobs.refresh_company_logos(opts)

    Mix.shell().info("Refreshed #{companies} company logos")
  end

  defp parse_args(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [force: :boolean, limit: :integer]
      )

    opts
  end
end
