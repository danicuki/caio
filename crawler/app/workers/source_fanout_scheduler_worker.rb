require "sidekiq/api"

class SourceFanoutSchedulerWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform
    target_depth = Integer(ENV.fetch("SOURCE_FETCH_TARGET_QUEUE_DEPTH", "500"))
    current_depth = Sidekiq::Queue.new("source_fetchers").size

    SourceFanoutWorker.perform_async if current_depth < target_depth
    self.class.perform_in(Integer(ENV.fetch("SOURCE_FANOUT_INTERVAL_SECONDS", "120")))
  end
end
