class CrawlSourceWorker
  include Sidekiq::Job

  sidekiq_options queue: :crawlers, retry: 5

  def perform(source_id)
    source = JobSource.find(source_id)
    run = source.crawl_runs.create!(started_at: Time.current)

    records = Crawler::SourceRegistry.build(source).fetch
    imported = Crawler::Importer.new(source).import(records)

    source.update!(last_crawled_at: Time.current)
    run.update!(
      status: "succeeded",
      fetched_count: records.size,
      imported_count: imported,
      finished_at: Time.current
    )
  rescue StandardError => e
    run&.update!(
      status: "failed",
      error_message: "#{e.class}: #{e.message}",
      finished_at: Time.current
    )
    raise
  end
end

