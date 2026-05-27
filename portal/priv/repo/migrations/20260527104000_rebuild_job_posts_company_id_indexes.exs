defmodule Portal.Repo.Migrations.RebuildJobPostsCompanyIdIndexes do
  use Ecto.Migration

  def up do
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_id;")
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_published_at;")

    execute(
      "CREATE INDEX IF NOT EXISTS index_job_posts_company_id_id ON job_posts(company_id, id DESC);"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS index_job_posts_company_id_published_at ON job_posts(company_id, published_at);"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_id;")
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_published_at;")

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_company_id_id
    ON job_posts(company_id, id DESC)
    WHERE company_id IS NOT NULL AND company_id != '';
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_company_id_published_at
    ON job_posts(company_id, published_at)
    WHERE company_id IS NOT NULL AND company_id != '';
    """)
  end
end
