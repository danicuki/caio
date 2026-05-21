require Rails.root.join("lib/standalone/job_api_batch")

class LinkedinPageWorker
  include Sidekiq::Job

  sidekiq_options queue: :linkedin_pages, retry: 10

  sidekiq_retry_in do |count, exception, _jobhash|
    if exception.is_a?(Standalone::RateLimited)
      Integer(ENV.fetch("LINKEDIN_RATE_LIMIT_RETRY_SECONDS", "600")) + (count * 300) + rand(120)
    else
      (count + 1) * 60
    end
  end

  def perform(keyword, location, start)
    sleep(Float(ENV.fetch("LINKEDIN_PAGE_SLEEP_SECONDS", "2.0")))

    source = Standalone::Sources::LinkedinPublic.new
    jobs = source.send(:fetch_page, keyword: keyword, location: location.to_s, start: Integer(start))
    JobPostImportWorker.enqueue("linkedin", jobs)
  rescue Standalone::RateLimited => e
    raise
  rescue StandardError => e
    raise
  end

end
