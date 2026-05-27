defmodule Portal.Repo.Migrations.CreateCompaniesAndLinkJobs do
  use Ecto.Migration

  @company_slug_sql """
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
  '-'))
  """

  def up do
    create_if_not_exists table(:companies, primary_key: false) do
      add :id, :text, primary_key: true
      add :name, :text, null: false
      add :logo_url, :text
      add :website_url, :text
      add :description, :text
      add :open_jobs_count, :integer, null: false, default: 0
      add :source_count, :integer, null: false, default: 0
      add :location_count, :integer, null: false, default: 0
      add :remote_count, :integer, null: false, default: 0
      add :salary_count, :integer, null: false, default: 0
      add :latest_posted_at, :text
      add :top_locations_json, :text, null: false, default: "[]"
      add :top_sources_json, :text, null: false, default: "[]"
      add :refreshed_at, :text
      add :created_at, :text, null: false
      add :updated_at, :text, null: false
    end

    create_if_not_exists table(:company_aliases) do
      add :company_id, references(:companies, type: :text, column: :id, on_delete: :delete_all),
        null: false

      add :normalized_name, :text, null: false
      add :display_name, :text, null: false
      add :jobs_count, :integer, null: false, default: 0
      add :created_at, :text, null: false
      add :updated_at, :text, null: false
    end

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS index_company_aliases_normalized_name ON company_aliases(normalized_name);"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS index_company_aliases_company_id ON company_aliases(company_id);"
    )

    add_column_if_missing("job_posts", "company_id", "TEXT")

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_company_id_id
    ON job_posts(company_id, id DESC);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_job_posts_company_id_published_at
    ON job_posts(company_id, published_at);
    """)

    backfill_companies()
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_published_at;")
    execute("DROP INDEX IF EXISTS index_job_posts_company_id_id;")
    execute("DROP INDEX IF EXISTS index_company_aliases_company_id;")
    execute("DROP INDEX IF EXISTS index_company_aliases_normalized_name;")
    drop_if_exists table(:company_aliases)
    drop_if_exists table(:companies)
  end

  defp backfill_companies do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    cutoff = Date.utc_today() |> Date.add(-183) |> Date.to_iso8601()

    execute("""
    INSERT OR IGNORE INTO companies(id, name, created_at, updated_at)
    SELECT slug, name, '#{now}', '#{now}'
    FROM (
      SELECT #{@company_slug_sql} AS slug, min(trim(company)) AS name
      FROM job_posts
      WHERE company IS NOT NULL AND trim(company) != ''
      GROUP BY #{@company_slug_sql}
    )
    WHERE slug IS NOT NULL AND slug != '';
    """)

    execute("""
    INSERT INTO company_aliases(company_id, normalized_name, display_name, jobs_count, created_at, updated_at)
    SELECT slug, normalized_name, display_name, jobs_count, '#{now}', '#{now}'
    FROM (
      SELECT
        #{@company_slug_sql} AS slug,
        lower(trim(company)) AS normalized_name,
        min(trim(company)) AS display_name,
        count(*) AS jobs_count
      FROM job_posts
      WHERE company IS NOT NULL AND trim(company) != ''
      GROUP BY lower(trim(company)), #{@company_slug_sql}
    )
    WHERE slug IS NOT NULL AND slug != ''
    ON CONFLICT(normalized_name) DO UPDATE SET
      company_id = excluded.company_id,
      display_name = excluded.display_name,
      jobs_count = excluded.jobs_count,
      updated_at = excluded.updated_at;
    """)

    execute("""
    UPDATE job_posts
    SET company_id = (
      SELECT company_id
      FROM company_aliases
      WHERE company_aliases.normalized_name = lower(trim(job_posts.company))
      LIMIT 1
    )
    WHERE company IS NOT NULL
      AND trim(company) != ''
      AND (
        company_id IS NULL
        OR company_id = ''
        OR company_id != (
          SELECT company_id
          FROM company_aliases
          WHERE company_aliases.normalized_name = lower(trim(job_posts.company))
          LIMIT 1
        )
      );
    """)

    execute("""
    INSERT INTO companies(
      id,
      name,
      open_jobs_count,
      source_count,
      location_count,
      remote_count,
      salary_count,
      latest_posted_at,
      refreshed_at,
      created_at,
      updated_at
    )
    SELECT
      j.company_id,
      min(trim(j.company)),
      count(*),
      COUNT(DISTINCT NULLIF(lower(trim(j.source)), '')),
      COUNT(DISTINCT NULLIF(lower(trim(j.location_country)), '')),
      SUM(CASE WHEN j.remote = 1 OR lower(coalesce(j.location_scope, '')) LIKE '%remote%' THEN 1 ELSE 0 END),
      COUNT(NULLIF(j.salary, '')),
      max(j.published_at),
      '#{now}',
      '#{now}',
      '#{now}'
    FROM job_posts j
    WHERE j.company_id IS NOT NULL
      AND j.company_id != ''
      AND (j.published_at IS NULL OR j.published_at = '' OR j.published_at >= '#{cutoff}')
    GROUP BY j.company_id
    ON CONFLICT(id) DO UPDATE SET
      name = excluded.name,
      open_jobs_count = excluded.open_jobs_count,
      source_count = excluded.source_count,
      location_count = excluded.location_count,
      remote_count = excluded.remote_count,
      salary_count = excluded.salary_count,
      latest_posted_at = excluded.latest_posted_at,
      refreshed_at = excluded.refreshed_at,
      updated_at = excluded.updated_at;
    """)
  end

  defp add_column_if_missing(table_name, column_name, type) do
    existing_columns =
      repo().query!("PRAGMA table_info(#{table_name})")
      |> Map.fetch!(:rows)
      |> Enum.map(fn row -> Enum.at(row, 1) end)
      |> MapSet.new()

    unless MapSet.member?(existing_columns, column_name) do
      execute("ALTER TABLE #{table_name} ADD COLUMN #{column_name} #{type};")
    end
  end
end
