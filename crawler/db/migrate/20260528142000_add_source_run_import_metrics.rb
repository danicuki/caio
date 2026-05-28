class AddSourceRunImportMetrics < ActiveRecord::Migration[8.0]
  def up
    add_column :source_runs, :inserted_count, :integer, null: false, default: 0 unless column_exists?(:source_runs, :inserted_count)
    add_column :source_runs, :updated_count, :integer, null: false, default: 0 unless column_exists?(:source_runs, :updated_count)
    add_column :source_runs, :skipped_count, :integer, null: false, default: 0 unless column_exists?(:source_runs, :skipped_count)

    execute <<~SQL
      UPDATE source_runs
      SET updated_count = imported_count
      WHERE inserted_count = 0
        AND updated_count = 0
        AND skipped_count = 0
        AND imported_count > 0;
    SQL
  end

  def down
    remove_column :source_runs, :skipped_count if column_exists?(:source_runs, :skipped_count)
    remove_column :source_runs, :updated_count if column_exists?(:source_runs, :updated_count)
    remove_column :source_runs, :inserted_count if column_exists?(:source_runs, :inserted_count)
  end
end
