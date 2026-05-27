defmodule Portal.Repo.Migrations.CreateJobUrlOverrides do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:job_url_overrides) do
      add :source, :text, null: false
      add :source_key, :text, null: false
      add :apply_url, :text, null: false
      add :reason, :text
      add :created_at, :text, null: false
      add :updated_at, :text, null: false
    end

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS index_job_url_overrides_source_key
    ON job_url_overrides(source, source_key);
    """)

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    execute("""
    INSERT INTO job_url_overrides(source, source_key, apply_url, reason, created_at, updated_at)
    VALUES (
      'linkedin',
      '4390863705',
      'https://careers.terracon.com/job/midvale/supervisor-project-coordination/37184/85966092016',
      'LinkedIn listing points to employer-hosted Terracon application',
      '#{now}',
      '#{now}'
    )
    ON CONFLICT(source, source_key) DO UPDATE SET
      apply_url = excluded.apply_url,
      reason = excluded.reason,
      updated_at = excluded.updated_at;
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_job_url_overrides_source_key;")
    drop_if_exists table(:job_url_overrides)
  end
end
