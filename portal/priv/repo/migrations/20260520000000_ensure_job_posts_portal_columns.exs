defmodule Portal.Repo.Migrations.EnsureJobPostsPortalColumns do
  use Ecto.Migration

  @columns [
    {"source", "TEXT"},
    {"salary_min", "REAL"},
    {"salary_max", "REAL"},
    {"salary_currency", "TEXT"},
    {"salary_period", "TEXT"},
    {"location_city", "TEXT"},
    {"location_state", "TEXT"},
    {"location_country", "TEXT"},
    {"location_continent", "TEXT"},
    {"location_scope", "TEXT"}
  ]

  def up do
    existing_columns =
      repo().query!("PRAGMA table_info(job_posts)")
      |> Map.fetch!(:rows)
      |> Enum.map(fn row -> Enum.at(row, 1) end)
      |> MapSet.new()

    Enum.each(@columns, fn {name, type} ->
      unless MapSet.member?(existing_columns, name) do
        execute("ALTER TABLE job_posts ADD COLUMN #{name} #{type};")
      end
    end)

    if table_exists?("job_sources") do
      execute("""
      UPDATE job_posts
      SET source = (
        SELECT adapter
        FROM job_sources
        WHERE job_sources.id = job_posts.job_source_id
      )
      WHERE source IS NULL;
      """)
    end
  end

  def down do
    :ok
  end

  defp table_exists?(table_name) do
    %{rows: rows} =
      repo().query!("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [table_name])

    rows != []
  end
end
