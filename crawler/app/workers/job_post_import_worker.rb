require Rails.root.join("lib/standalone/job_api_batch")
require "set"

class JobPostImportWorker
  include Sidekiq::Job

  sidekiq_options queue: :job_writes, retry: 10

  def self.enqueue(source, jobs)
    return if jobs.empty?

    new_jobs, update_jobs = split_new_jobs(source, jobs)

    enqueue_batch(source, new_jobs, :job_writes_new)
    enqueue_batch(source, update_jobs, :job_writes_updates)
  end

  def self.enqueue_batch(source, jobs, queue)
    return if jobs.empty?

    set(queue: queue).perform_async(source, JobBatchSpool.write(source, jobs))
  end

  def self.split_new_jobs(source, jobs)
    existing_keys, existing_urls = existing_identifiers(source, jobs)

    jobs.partition do |job|
      source_key = job_identifier(job, :source_key)
      source_url = job_identifier(job, :source_url)

      !existing_keys.include?(source_key) && !existing_urls.include?(source_url)
    end
  rescue StandardError => e
    warn "job import priority classification failed source=#{source}: #{e.class}: #{e.message}"
    [jobs, []]
  end

  def self.existing_identifiers(source, jobs)
    source_keys = jobs.filter_map { |job| job_identifier(job, :source_key) }.uniq
    source_urls = jobs.filter_map { |job| job_identifier(job, :source_url) }.uniq

    existing_keys =
      if source_keys.empty?
        Set.new
      else
        JobPost.where(source: source, source_key: source_keys).pluck(:source_key).map(&:to_s).to_set
      end

    existing_urls =
      if source_urls.empty?
        Set.new
      else
        JobPost.where(source_url: source_urls).pluck(:source_url).map(&:to_s).to_set
      end

    [existing_keys, existing_urls]
  end

  def self.job_identifier(job, key)
    (job[key] || job[key.to_s]).to_s.presence
  end

  def perform(source, jobs_payload)
    jobs = JobBatchSpool.read(jobs_payload)
    stats = import_jobs(source, jobs)
    JobBatchSpool.delete(jobs_payload)

    SourceRun.create!(
      source: source,
      status: "imported",
      fetched_count: jobs.size,
      imported_count: stats.imported_count,
      inserted_count: stats.inserted_count,
      updated_count: stats.updated_count,
      skipped_count: stats.skipped_count,
      created_at: Time.current
    )
  rescue JobBatchSpool::MissingSpoolFile => e
    SourceRun.create!(
      source: source,
      status: "import_spool_missing",
      fetched_count: 0,
      imported_count: 0,
      inserted_count: 0,
      updated_count: 0,
      skipped_count: 0,
      error_message: e.message,
      created_at: Time.current
    )
  rescue StandardError => e
    SourceRun.create!(
      source: source,
      status: "import_failed",
      fetched_count: 0,
      imported_count: 0,
      inserted_count: 0,
      updated_count: 0,
      skipped_count: 0,
      error_message: "#{e.class}: #{e.message}",
      created_at: Time.current
    )
    raise
  end

  private

  def database
    @database ||= Standalone::Database.new(database_path)
  end

  def import_jobs(source, jobs)
    if database.respond_to?(:upsert_jobs_with_stats)
      database.upsert_jobs_with_stats(source, jobs)
    else
      Standalone::ImportStats.from(database.upsert_jobs(source, jobs))
    end
  end

  def database_path
    ENV["JOB_CRAWLER_DATABASE"].presence ||
      ActiveRecord::Base.connection_db_config.database ||
      Rails.root.join("db/development.sqlite3").to_s
  end
end
