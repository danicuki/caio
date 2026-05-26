require Rails.root.join("lib/standalone/job_api_batch")

class JobPostImportWorker
  include Sidekiq::Job

  sidekiq_options queue: :job_writes, retry: 10

  def self.enqueue(source, jobs)
    return if jobs.empty?

    perform_async(source, JobBatchSpool.write(source, jobs))
  end

  def perform(source, jobs_payload)
    jobs = JobBatchSpool.read(jobs_payload)
    imported = database.upsert_jobs(source, jobs)
    JobBatchSpool.delete(jobs_payload)

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
    @database ||= Standalone::Database.new(database_path)
  end

  def database_path
    ENV["JOB_CRAWLER_DATABASE"].presence ||
      ActiveRecord::Base.connection_db_config.database ||
      Rails.root.join("db/development.sqlite3").to_s
  end
end
