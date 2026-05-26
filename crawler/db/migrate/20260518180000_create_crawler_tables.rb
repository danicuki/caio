class CreateCrawlerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :job_sources do |t|
      t.string :name, null: false
      t.string :adapter, null: false
      t.string :base_url, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :crawl_interval_minutes, null: false, default: 360
      t.datetime :last_crawled_at
      t.text :terms_note
      t.timestamps
    end

    add_index :job_sources, :adapter, unique: true
    add_index :job_sources, :enabled

    create_table :job_posts do |t|
      t.references :job_source, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :title, null: false
      t.string :company
      t.string :location
      t.boolean :remote
      t.string :employment_type
      t.string :category
      t.string :salary
      t.string :source_url, null: false
      t.datetime :published_at
      t.datetime :expires_at
      t.text :tags_json
      t.text :description
      t.text :raw_json
      t.float :salary_min
      t.float :salary_max
      t.string :salary_currency
      t.string :salary_period
      t.string :location_city
      t.string :location_state
      t.string :location_country
      t.string :location_continent
      t.string :location_scope
      t.timestamps
    end

    add_index :job_posts, %i[job_source_id source_key], unique: true
    add_index :job_posts, :published_at
    add_index :job_posts, :company
    add_index :job_posts, :location
    add_index :job_posts, :remote
    add_index :job_posts, :category

    create_table :crawl_runs do |t|
      t.references :job_source, null: false, foreign_key: true
      t.string :status, null: false, default: "running"
      t.integer :fetched_count, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
  end
end
