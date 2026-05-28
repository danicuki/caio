defmodule Portal.Repo.Migrations.AddCrawlerObservabilityIndexes do
  use Ecto.Migration

  def up do
    if table_exists?("job_posts") do
      execute("CREATE INDEX IF NOT EXISTS index_job_posts_created_at ON job_posts(created_at)")

      execute(
        "CREATE INDEX IF NOT EXISTS index_job_posts_source_created_at ON job_posts(source, created_at)"
      )
    end

    if table_exists?("source_runs") do
      execute(
        "CREATE INDEX IF NOT EXISTS index_source_runs_created_at ON source_runs(created_at)"
      )

      execute(
        "CREATE INDEX IF NOT EXISTS index_source_runs_source_created_at ON source_runs(source, created_at)"
      )
    end
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_created_at")
    execute("DROP INDEX IF EXISTS index_job_posts_source_created_at")
    execute("DROP INDEX IF EXISTS index_source_runs_created_at")
    execute("DROP INDEX IF EXISTS index_source_runs_source_created_at")
  end

  defp table_exists?(table) do
    %{rows: rows} =
      repo().query!(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        [table]
      )

    rows != []
  end
end
