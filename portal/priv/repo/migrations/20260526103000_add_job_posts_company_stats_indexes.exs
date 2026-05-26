defmodule Portal.Repo.Migrations.AddJobPostsCompanyStatsIndexes do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_public
    ON job_posts(lower(trim(company)), published_at)
    WHERE company IS NOT NULL AND trim(company) != '';
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_active
    ON job_posts(lower(trim(company)), COALESCE(NULLIF(published_at, ''), '9999-12-31'))
    WHERE company IS NOT NULL AND trim(company) != '';
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_source
    ON job_posts(lower(trim(company)), lower(trim(source)))
    WHERE company IS NOT NULL AND trim(company) != ''
      AND source IS NOT NULL AND trim(source) != '';
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_country
    ON job_posts(lower(trim(company)), lower(trim(location_country)))
    WHERE company IS NOT NULL AND trim(company) != ''
      AND location_country IS NOT NULL AND trim(location_country) != '';
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_normalized_company_country;")
    execute("DROP INDEX IF EXISTS index_job_posts_normalized_company_source;")
    execute("DROP INDEX IF EXISTS index_job_posts_normalized_company_active;")
    execute("DROP INDEX IF EXISTS index_job_posts_normalized_company_public;")
  end
end
