class EnqueueCrawlBatchWorker
  include Sidekiq::Job

  def perform
    JobSource.enabled.find_each do |source|
      CrawlSourceWorker.perform_async(source.id)
    end
  end
end

