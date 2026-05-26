class ArbeitnowDescriptionRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform(limit = nil)
    StructuredDescriptionRepairWorker.new.perform("arbeitnow", limit)
  end
end
