defmodule Portal.Repo.Migrations.AddJobPostsNewestOrderIndex do
  use Ecto.Migration

  def up do
    if table_exists?("job_posts") do
      execute(
        "CREATE INDEX IF NOT EXISTS index_job_posts_published_at_id ON job_posts(published_at, id)"
      )
    end
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_published_at_id")
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
