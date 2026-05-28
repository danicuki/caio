defmodule Portal.Repo.Migrations.CreateSitemapFacets do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:sitemap_facets) do
      add :facet, :text, null: false
      add :label, :text, null: false
      add :jobs_count, :integer, null: false, default: 0
      add :latest_posted_at, :text
      add :refreshed_at, :utc_datetime, null: false
    end

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS sitemap_facets_facet_label_index
    ON sitemap_facets(facet, lower(label));
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS sitemap_facets_facet_jobs_count_index
    ON sitemap_facets(facet, jobs_count DESC, label);
    """)
  end
end
