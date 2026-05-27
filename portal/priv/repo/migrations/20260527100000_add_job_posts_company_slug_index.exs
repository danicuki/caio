defmodule Portal.Repo.Migrations.AddJobPostsCompanySlugIndex do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_company_slug_public
    ON job_posts(
      lower(trim(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(company, '&', 'and'),
                      '''', ''),
                    '.', ''),
                  ',', ''),
                '(', ''),
              ')', ''),
            '/', '-'),
          ' ', '-'),
        '--', '-'),
      '-')),
      published_at
    )
    WHERE company IS NOT NULL AND trim(company) != '';
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_company_slug_public;")
  end
end
