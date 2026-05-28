defmodule Portal.Repo.Migrations.AddSourceRunImportMetrics do
  use Ecto.Migration

  @columns [
    {"inserted_count", "INTEGER NOT NULL DEFAULT 0"},
    {"updated_count", "INTEGER NOT NULL DEFAULT 0"},
    {"skipped_count", "INTEGER NOT NULL DEFAULT 0"}
  ]

  def up do
    if table_exists?("source_runs") do
      existing_columns =
        repo().query!("PRAGMA table_info(source_runs)")
        |> Map.fetch!(:rows)
        |> Enum.map(fn row -> Enum.at(row, 1) end)
        |> MapSet.new()

      Enum.each(@columns, fn {name, type} ->
        unless MapSet.member?(existing_columns, name) do
          execute("ALTER TABLE source_runs ADD COLUMN #{name} #{type};")
        end
      end)

      execute("""
      UPDATE source_runs
      SET updated_count = imported_count
      WHERE inserted_count = 0
        AND updated_count = 0
        AND skipped_count = 0
        AND imported_count > 0;
      """)
    end
  end

  def down do
    :ok
  end

  defp table_exists?(table_name) do
    %{rows: rows} =
      repo().query!("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [table_name])

    rows != []
  end
end
