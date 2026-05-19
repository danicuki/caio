require "sidekiq/api"

class LinkedinSchedulerWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform
    target_depth = Integer(ENV.fetch("LINKEDIN_TARGET_QUEUE_DEPTH", "1000"))
    detail_target_depth = Integer(ENV.fetch("LINKEDIN_DETAIL_TARGET_QUEUE_DEPTH", "300"))
    batch_size = Integer(ENV.fetch("LINKEDIN_ENQUEUE_BATCH_SIZE", "250"))
    current_depth = Sidekiq::Queue.new("linkedin_pages").size
    detail_depth = Sidekiq::Queue.new("linkedin_details").size

    LinkedinEnqueueWorker.perform_async(batch_size) if current_depth < target_depth
    LinkedinDescriptionBackfillWorker.perform_async if detail_depth < detail_target_depth
    self.class.perform_in(Integer(ENV.fetch("LINKEDIN_SCHEDULER_INTERVAL_SECONDS", "60")))
  end
end
