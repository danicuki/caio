defmodule Portal.CrawlerStats do
  @moduledoc false

  alias Portal.Repo

  @query_opts [timeout: 30_000]
  @cache_table :portal_crawler_stats_cache
  @cache_key :snapshot
  @cache_ttl_ms 60_000

  def snapshot do
    case cached_snapshot() do
      {:ok, snapshot} ->
        snapshot

      :miss ->
        snapshot = build_snapshot()
        put_cached_snapshot(snapshot)
        snapshot
    end
  end

  def build_snapshot do
    cutoffs = cutoffs()

    %{
      summary: summary(cutoffs),
      hourly: hourly(cutoffs),
      daily: daily(cutoffs),
      sources: sources(cutoffs),
      states: source_states(),
      recent_errors: recent_errors()
    }
  end

  defp summary(cutoffs) do
    job_stats =
      one(
        """
        SELECT count(*) AS total_jobs, max(created_at) AS latest_job_at
        FROM job_posts
        """,
        []
      )

    recent_job_stats =
      one(
        """
        SELECT
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS jobs_last_hour,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS jobs_last_day,
          count(*) AS jobs_last_week
        FROM job_posts
        WHERE created_at >= ?
        """,
        [cutoffs.job_hour, cutoffs.job_day, cutoffs.job_week]
      )

    run_stats =
      one(
        """
        SELECT
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS runs_last_hour,
          count(*) AS runs_last_day,
          SUM(fetched_count) AS fetched_last_day,
          SUM(imported_count) AS imported_last_day,
          SUM(inserted_count) AS inserted_last_day,
          SUM(updated_count) AS updated_last_day,
          SUM(skipped_count) AS skipped_last_day,
          SUM(CASE WHEN status != 'imported' THEN 1 ELSE 0 END) AS errors_last_day
        FROM source_runs
        WHERE created_at >= ?
        """,
        [cutoffs.source_hour, cutoffs.source_day]
      )

    latest_run =
      one(
        """
        SELECT created_at AS latest_run_at
        FROM source_runs
        ORDER BY id DESC
        LIMIT 1
        """,
        []
      )

    job_stats
    |> Map.merge(recent_job_stats)
    |> Map.merge(run_stats)
    |> Map.merge(latest_run)
  end

  defp hourly(cutoffs) do
    rows(
      """
      WITH job_hours AS (
        SELECT
          strftime('%Y-%m-%d %H:00', datetime(created_at)) AS bucket,
          count(*) AS new_jobs
        FROM job_posts
        WHERE created_at >= ?
        GROUP BY bucket
      ),
      run_hours AS (
        SELECT
          strftime('%Y-%m-%d %H:00', datetime(replace(created_at, ' UTC', ''))) AS bucket,
          count(*) AS runs,
          SUM(fetched_count) AS fetched,
          SUM(imported_count) AS imported,
          SUM(inserted_count) AS inserted,
          SUM(updated_count) AS updated,
          SUM(skipped_count) AS skipped,
          SUM(CASE WHEN status != 'imported' THEN 1 ELSE 0 END) AS errors
        FROM source_runs
        WHERE created_at >= ?
        GROUP BY bucket
      )
      SELECT
        COALESCE(job_hours.bucket, run_hours.bucket) AS bucket,
        COALESCE(job_hours.new_jobs, 0) AS new_jobs,
        COALESCE(run_hours.runs, 0) AS runs,
        COALESCE(run_hours.fetched, 0) AS fetched,
        COALESCE(run_hours.imported, 0) AS imported,
        COALESCE(run_hours.inserted, 0) AS inserted,
        COALESCE(run_hours.updated, 0) AS updated,
        COALESCE(run_hours.skipped, 0) AS skipped,
        COALESCE(run_hours.errors, 0) AS errors
      FROM job_hours
      FULL OUTER JOIN run_hours ON run_hours.bucket = job_hours.bucket
      ORDER BY bucket DESC
      LIMIT 24
      """,
      [cutoffs.job_day, cutoffs.source_day]
    )
  rescue
    _error -> hourly_without_full_join(cutoffs)
  end

  defp daily(cutoffs) do
    rows(
      """
      SELECT
        date(datetime(created_at)) AS bucket,
        count(*) AS new_jobs
      FROM job_posts
      WHERE created_at >= ?
      GROUP BY bucket
      ORDER BY bucket DESC
      LIMIT 14
      """,
      [cutoffs.job_14_days]
    )
  end

  defp sources(cutoffs) do
    rows(
      """
      WITH source_jobs AS (
        SELECT source, count(*) AS new_jobs_24h
        FROM job_posts
        WHERE created_at >= ?
        GROUP BY source
      ),
      source_runs_24h AS (
        SELECT
          source,
          count(*) AS runs_24h,
          SUM(fetched_count) AS fetched_24h,
          SUM(imported_count) AS imported_24h,
          SUM(inserted_count) AS inserted_24h,
          SUM(updated_count) AS updated_24h,
          SUM(skipped_count) AS skipped_24h,
          SUM(CASE WHEN status != 'imported' THEN 1 ELSE 0 END) AS errors_24h,
          max(created_at) AS last_run_at
        FROM source_runs
        WHERE created_at >= ?
        GROUP BY source
      ),
      active_sources AS (
        SELECT source FROM source_jobs
        UNION
        SELECT source FROM source_runs_24h
      )
      SELECT
        active_sources.source AS source,
        COALESCE(source_jobs.new_jobs_24h, 0) AS new_jobs_24h,
        COALESCE(source_runs_24h.runs_24h, 0) AS runs_24h,
        COALESCE(source_runs_24h.fetched_24h, 0) AS fetched_24h,
        COALESCE(source_runs_24h.imported_24h, 0) AS imported_24h,
        COALESCE(source_runs_24h.inserted_24h, 0) AS inserted_24h,
        COALESCE(source_runs_24h.updated_24h, 0) AS updated_24h,
        COALESCE(source_runs_24h.skipped_24h, 0) AS skipped_24h,
        COALESCE(source_runs_24h.errors_24h, 0) AS errors_24h,
        source_runs_24h.last_run_at AS last_run_at
      FROM active_sources
      LEFT JOIN source_runs_24h ON source_runs_24h.source = active_sources.source
      LEFT JOIN source_jobs ON source_jobs.source = active_sources.source
      ORDER BY new_jobs_24h DESC, imported_24h DESC, runs_24h DESC
      LIMIT 40
      """,
      [cutoffs.job_day, cutoffs.source_day]
    )
  end

  defp source_states do
    rows("""
    SELECT source, next_cursor, exhausted, last_error, updated_at
    FROM source_states
    ORDER BY datetime(replace(updated_at, ' UTC', '')) DESC
    LIMIT 60
    """)
  end

  defp recent_errors do
    rows("""
    SELECT source, status, fetched_count, imported_count, inserted_count, updated_count, skipped_count, error_message, created_at
    FROM source_runs
    WHERE status != 'imported' OR error_message IS NOT NULL
    ORDER BY id DESC
    LIMIT 25
    """)
  end

  defp hourly_without_full_join(cutoffs) do
    rows(
      """
      SELECT
        strftime('%Y-%m-%d %H:00', datetime(created_at)) AS bucket,
        count(*) AS new_jobs,
        0 AS runs,
        0 AS fetched,
        0 AS imported,
        0 AS inserted,
        0 AS updated,
        0 AS skipped,
        0 AS errors
      FROM job_posts
      WHERE created_at >= ?
      GROUP BY bucket
      ORDER BY bucket DESC
      LIMIT 24
      """,
      [cutoffs.job_day]
    )
  end

  defp cutoffs do
    %{
      job_hour: iso_cutoff(hours: 1),
      job_day: iso_cutoff(hours: 24),
      job_week: iso_cutoff(days: 7),
      job_14_days: iso_cutoff(days: 14),
      source_hour: text_cutoff(hours: 1),
      source_day: text_cutoff(hours: 24)
    }
  end

  defp iso_cutoff(opts) do
    opts
    |> seconds()
    |> then(&DateTime.add(DateTime.utc_now(), -&1, :second))
    |> DateTime.to_iso8601()
  end

  defp text_cutoff(opts) do
    opts
    |> seconds()
    |> then(&DateTime.add(DateTime.utc_now(), -&1, :second))
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  defp seconds(hours: hours), do: hours * 60 * 60
  defp seconds(days: days), do: days * 24 * 60 * 60

  defp one(sql, params) do
    case rows(sql, params) do
      [row | _] -> row
      [] -> %{}
    end
  end

  defp rows(sql, params \\ []) do
    result = Repo.query!(sql, params, @query_opts)

    Enum.map(result.rows, fn row ->
      result.columns
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  defp cached_snapshot do
    ensure_cache_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, @cache_key) do
      [{@cache_key, timestamp, snapshot}] when now - timestamp < @cache_ttl_ms -> {:ok, snapshot}
      _ -> :miss
    end
  end

  defp put_cached_snapshot(snapshot) do
    ensure_cache_table()
    :ets.insert(@cache_table, {@cache_key, System.monotonic_time(:millisecond), snapshot})
  end

  defp ensure_cache_table do
    :ets.new(@cache_table, [
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  rescue
    ArgumentError -> :ok
  end
end
