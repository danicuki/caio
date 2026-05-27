class AddCompanyIdToJobPosts < ActiveRecord::Migration[8.0]
  def up
    add_column :job_posts, :company_id, :string unless column_exists?(:job_posts, :company_id)

    execute <<~SQL
      CREATE INDEX IF NOT EXISTS index_job_posts_company_id_id
      ON job_posts(company_id, id DESC);
    SQL

    execute <<~SQL
      CREATE INDEX IF NOT EXISTS index_job_posts_company_id_published_at
      ON job_posts(company_id, published_at);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_job_posts_company_id_published_at;"
    execute "DROP INDEX IF EXISTS index_job_posts_company_id_id;"
    remove_column :job_posts, :company_id if column_exists?(:job_posts, :company_id)
  end
end
