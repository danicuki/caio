defmodule Portal.Repo.Migrations.ExpandJobPostsFtsLocationFields do
  use Ecto.Migration

  def up do
    execute("DROP TRIGGER IF EXISTS job_posts_au;")
    execute("DROP TRIGGER IF EXISTS job_posts_ad;")
    execute("DROP TRIGGER IF EXISTS job_posts_ai;")
    execute("DROP TABLE IF EXISTS job_posts_fts;")

    execute("""
    CREATE VIRTUAL TABLE job_posts_fts USING fts5(
      title,
      company,
      location,
      location_city,
      location_state,
      location_country,
      location_continent,
      category,
      tags_json,
      description,
      content='job_posts',
      content_rowid='id'
    );
    """)

    execute("""
    INSERT INTO job_posts_fts(
      rowid,
      title,
      company,
      location,
      location_city,
      location_state,
      location_country,
      location_continent,
      category,
      tags_json,
      description
    )
    SELECT
      id,
      title,
      company,
      location,
      location_city,
      location_state,
      location_country,
      location_continent,
      category,
      tags_json,
      description
    FROM job_posts;
    """)

    create_triggers()
  end

  def down do
    execute("DROP TRIGGER IF EXISTS job_posts_au;")
    execute("DROP TRIGGER IF EXISTS job_posts_ad;")
    execute("DROP TRIGGER IF EXISTS job_posts_ai;")
    execute("DROP TABLE IF EXISTS job_posts_fts;")

    execute("""
    CREATE VIRTUAL TABLE job_posts_fts USING fts5(
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
    FROM job_posts;
    """)

    execute("""
    CREATE TRIGGER job_posts_ai AFTER INSERT ON job_posts BEGIN
      INSERT INTO job_posts_fts(rowid, title, company, location, category, tags_json, description)
      VALUES (new.id, new.title, new.company, new.location, new.category, new.tags_json, new.description);
    END;
    """)

    execute("""
    CREATE TRIGGER job_posts_ad AFTER DELETE ON job_posts BEGIN
      INSERT INTO job_posts_fts(job_posts_fts, rowid, title, company, location, category, tags_json, description)
      VALUES ('delete', old.id, old.title, old.company, old.location, old.category, old.tags_json, old.description);
    END;
    """)

    execute("""
    CREATE TRIGGER job_posts_au AFTER UPDATE ON job_posts BEGIN
      INSERT INTO job_posts_fts(job_posts_fts, rowid, title, company, location, category, tags_json, description)
      VALUES ('delete', old.id, old.title, old.company, old.location, old.category, old.tags_json, old.description);
      INSERT INTO job_posts_fts(rowid, title, company, location, category, tags_json, description)
      VALUES (new.id, new.title, new.company, new.location, new.category, new.tags_json, new.description);
    END;
    """)
  end

  defp create_triggers do
    execute("""
    CREATE TRIGGER job_posts_ai AFTER INSERT ON job_posts BEGIN
      INSERT INTO job_posts_fts(
        rowid,
        title,
        company,
        location,
        location_city,
        location_state,
        location_country,
        location_continent,
        category,
        tags_json,
        description
      )
      VALUES (
        new.id,
        new.title,
        new.company,
        new.location,
        new.location_city,
        new.location_state,
        new.location_country,
        new.location_continent,
        new.category,
        new.tags_json,
        new.description
      );
    END;
    """)

    execute("""
    CREATE TRIGGER job_posts_ad AFTER DELETE ON job_posts BEGIN
      INSERT INTO job_posts_fts(
        job_posts_fts,
        rowid,
        title,
        company,
        location,
        location_city,
        location_state,
        location_country,
        location_continent,
        category,
        tags_json,
        description
      )
      VALUES (
        'delete',
        old.id,
        old.title,
        old.company,
        old.location,
        old.location_city,
        old.location_state,
        old.location_country,
        old.location_continent,
        old.category,
        old.tags_json,
        old.description
      );
    END;
    """)

    execute("""
    CREATE TRIGGER job_posts_au AFTER UPDATE ON job_posts BEGIN
      INSERT INTO job_posts_fts(
        job_posts_fts,
        rowid,
        title,
        company,
        location,
        location_city,
        location_state,
        location_country,
        location_continent,
        category,
        tags_json,
        description
      )
      VALUES (
        'delete',
        old.id,
        old.title,
        old.company,
        old.location,
        old.location_city,
        old.location_state,
        old.location_country,
        old.location_continent,
        old.category,
        old.tags_json,
        old.description
      );
      INSERT INTO job_posts_fts(
        rowid,
        title,
        company,
        location,
        location_city,
        location_state,
        location_country,
        location_continent,
        category,
        tags_json,
        description
      )
      VALUES (
        new.id,
        new.title,
        new.company,
        new.location,
        new.location_city,
        new.location_state,
        new.location_country,
        new.location_continent,
        new.category,
        new.tags_json,
        new.description
      );
    END;
    """)
  end
end
