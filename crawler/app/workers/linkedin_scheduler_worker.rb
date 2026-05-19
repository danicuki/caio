require "sidekiq/api"

class LinkedinSchedulerWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform
    target_depth = Integer(ENV.fetch("LINKEDIN_TARGET_QUEUE_DEPTH", "1000"))
    batch_size = Integer(ENV.fetch("LINKEDIN_ENQUEUE_BATCH_SIZE", "250"))
    current_depth = Sidekiq::Queue.new("linkedin_pages").size

    LinkedinEnqueueWorker.perform_async(batch_size) if current_depth < target_depth
    self.class.perform_in(Integer(ENV.fetch("LINKEDIN_SCHEDULER_INTERVAL_SECONDS", "60")))
  end
end
