defmodule Portal.CrawlerStats do
  @moduledoc false

  alias Portal.Repo

  @query_opts [timeout: 30_000]

  def snapshot do
    cutoffs = cutoffs()

    %{
      summary: summary(cutoffs),
      hourly: hourly(cutoffs),
      daily: daily(cutoffs),
      sources: sources(cutoffs),
      states: source_states(),
      recent_errors: recent_errors(),
      recent_runs: recent_runs()
    }
  end

  defp summary(cutoffs) do
    job_stats =
      one(
        """
        SELECT
          count(*) AS total_jobs,
          max(created_at) AS latest_job_at,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS jobs_last_hour,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS jobs_last_day,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS jobs_last_week
        FROM job_posts
        """,
        [cutoffs.job_hour, cutoffs.job_day, cutoffs.job_week]
      )

    run_stats =
      one(
        """
        SELECT
          count(*) AS runs_total,
          max(created_at) AS latest_run_at,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS runs_last_hour,
          SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS runs_last_day,
          SUM(CASE WHEN created_at >= ? THEN fetched_count ELSE 0 END) AS fetched_last_day,
          SUM(CASE WHEN created_at >= ? THEN imported_count ELSE 0 END) AS imported_last_day,
          SUM(CASE WHEN status != 'imported' AND created_at >= ? THEN 1 ELSE 0 END) AS errors_last_day
        FROM source_runs
        """,
        [
          cutoffs.source_hour,
          cutoffs.source_day,
          cutoffs.source_day,
          cutoffs.source_day,
          cutoffs.source_day
        ]
      )

    Map.merge(job_stats, run_stats)
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
      WITH job_days AS (
        SELECT
          date(datetime(created_at)) AS bucket,
          count(*) AS new_jobs
        FROM job_posts
        WHERE created_at >= ?
        GROUP BY bucket
      ),
      run_days AS (
        SELECT
          date(datetime(replace(created_at, ' UTC', ''))) AS bucket,
          count(*) AS runs,
          SUM(fetched_count) AS fetched,
          SUM(imported_count) AS imported,
          SUM(CASE WHEN status != 'imported' THEN 1 ELSE 0 END) AS errors
        FROM source_runs
        WHERE created_at >= ?
        GROUP BY bucket
      )
      SELECT
        job_days.bucket AS bucket,
        COALESCE(job_days.new_jobs, 0) AS new_jobs,
        COALESCE(run_days.runs, 0) AS runs,
        COALESCE(run_days.fetched, 0) AS fetched,
        COALESCE(run_days.imported, 0) AS imported,
        COALESCE(run_days.errors, 0) AS errors
      FROM job_days
      LEFT JOIN run_days ON run_days.bucket = job_days.bucket
      ORDER BY job_days.bucket DESC
      LIMIT 14
      """,
      [cutoffs.job_14_days, cutoffs.source_14_days]
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
          SUM(CASE WHEN status != 'imported' THEN 1 ELSE 0 END) AS errors_24h,
          max(created_at) AS last_run_at
        FROM source_runs
        WHERE created_at >= ?
        GROUP BY source
      ),
      source_runs_all AS (
        SELECT source, max(created_at) AS last_seen_at
        FROM source_runs
        GROUP BY source
      )
      SELECT
        COALESCE(source_runs_24h.source, source_jobs.source, source_runs_all.source) AS source,
        COALESCE(source_jobs.new_jobs_24h, 0) AS new_jobs_24h,
        COALESCE(source_runs_24h.runs_24h, 0) AS runs_24h,
        COALESCE(source_runs_24h.fetched_24h, 0) AS fetched_24h,
        COALESCE(source_runs_24h.imported_24h, 0) AS imported_24h,
        COALESCE(source_runs_24h.errors_24h, 0) AS errors_24h,
        COALESCE(source_runs_24h.last_run_at, source_runs_all.last_seen_at) AS last_run_at
      FROM source_runs_all
      LEFT JOIN source_runs_24h ON source_runs_24h.source = source_runs_all.source
      LEFT JOIN source_jobs ON source_jobs.source = source_runs_all.source
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
    SELECT source, status, fetched_count, imported_count, error_message, created_at
    FROM source_runs
    WHERE status != 'imported' OR error_message IS NOT NULL
    ORDER BY id DESC
    LIMIT 25
    """)
  end

  defp recent_runs do
    rows("""
    SELECT source, status, fetched_count, imported_count, error_message, created_at
    FROM source_runs
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
      source_day: text_cutoff(hours: 24),
      source_14_days: text_cutoff(days: 14)
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
end
