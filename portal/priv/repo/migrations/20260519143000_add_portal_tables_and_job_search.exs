defmodule Portal.Repo.Migrations.AddPortalTablesAndJobSearch do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:job_posts) do
      add :source, :text, null: false
      add :source_key, :text, null: false
      add :title, :text, null: false
      add :company, :text
      add :location, :text
      add :remote, :integer, default: 0
      add :employment_type, :text
      add :category, :text
      add :salary, :text
      add :source_url, :text, null: false
      add :published_at, :text
      add :tags_json, :text
      add :description, :text
      add :salary_min, :float
      add :salary_max, :float
      add :salary_currency, :text
      add :salary_period, :text
      add :location_city, :text
      add :location_state, :text
      add :location_country, :text
      add :location_continent, :text
      add :location_scope, :text
      add :created_at, :text
      add :updated_at, :text
    end

    create_if_not_exists table(:leads) do
      add :email, :text, null: false
      add :linkedin_url, :text
      add :target_role, :text
      add :target_location, :text
      add :consent_job_help, :boolean, null: false, default: false
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    execute("CREATE UNIQUE INDEX IF NOT EXISTS leads_email_index ON leads(email);")

    create_if_not_exists table(:job_interests) do
      add :lead_id, references(:leads, on_delete: :nilify_all)
      add :job_post_id, :integer, null: false
      add :session_token, :text
      add :source_url, :text, null: false
      add :created_at, :utc_datetime, null: false
    end

    execute("CREATE INDEX IF NOT EXISTS job_interests_lead_id_index ON job_interests(lead_id);")

    execute(
      "CREATE INDEX IF NOT EXISTS job_interests_job_post_id_index ON job_interests(job_post_id);"
    )

    execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS job_posts_fts USING fts5(
      title,
      company,
      location,
      category,
      tags_json,
      description,
      content='job_posts',
      content_rowid='id'
    );
    """)

    execute("""
    INSERT INTO job_posts_fts(rowid, title, company, location, category, tags_json, description)
    SELECT id, title, company, location, category, tags_json, description
    FROM job_posts
    WHERE id NOT IN (SELECT rowid FROM job_posts_fts);
    """)

    execute("""
    CREATE TRIGGER IF NOT EXISTS job_posts_ai AFTER INSERT ON job_posts BEGIN
      INSERT INTO job_posts_fts(rowid, title, company, location, category, tags_json, description)
      VALUES (new.id, new.title, new.company, new.location, new.category, new.tags_json, new.description);
    END;
    """)

    execute("""
    CREATE TRIGGER IF NOT EXISTS job_posts_ad AFTER DELETE ON job_posts BEGIN
      INSERT INTO job_posts_fts(job_posts_fts, rowid, title, company, location, category, tags_json, description)
      VALUES ('delete', old.id, old.title, old.company, old.location, old.category, old.tags_json, old.description);
    END;
    """)

    execute("""
    CREATE TRIGGER IF NOT EXISTS job_posts_au AFTER UPDATE ON job_posts BEGIN
      INSERT INTO job_posts_fts(job_posts_fts, rowid, title, company, location, category, tags_json, description)
      VALUES ('delete', old.id, old.title, old.company, old.location, old.category, old.tags_json, old.description);
      INSERT INTO job_posts_fts(rowid, title, company, location, category, tags_json, description)
      VALUES (new.id, new.title, new.company, new.location, new.category, new.tags_json, new.description);
    END;
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS job_posts_au;")
    execute("DROP TRIGGER IF EXISTS job_posts_ad;")
    execute("DROP TRIGGER IF EXISTS job_posts_ai;")
    execute("DROP TABLE IF EXISTS job_posts_fts;")
    drop_if_exists table(:job_interests)
    drop_if_exists table(:leads)
  end
end
