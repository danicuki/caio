require Rails.root.join("lib/standalone/job_api_batch")

class JobPostImportWorker
  include Sidekiq::Job

  sidekiq_options queue: :job_writes, retry: 10

  def perform(source, jobs_json)
    jobs = JSON.parse(jobs_json, symbolize_names: true)
    imported = database.upsert_jobs(source, jobs)
    SourceRun.create!(
      source: source,
      status: "imported",
      fetched_count: jobs.size,
      imported_count: imported,
      created_at: Time.current
    )
  rescue StandardError => e
    SourceRun.create!(
      source: source,
      status: "import_failed",
      fetched_count: 0,
      imported_count: 0,
      error_message: "#{e.class}: #{e.message}",
      created_at: Time.current
    )
    raise
  end

  private

  def database
    @database ||= Standalone::Database.new(Rails.root.join("db/development.sqlite3").to_s)
  end
end
