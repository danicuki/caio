class HimalayasDescriptionRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  SOURCES = %w[himalayas himalayas_search].freeze

  def perform(limit = nil)
    limit ||= Integer(ENV.fetch("HIMALAYAS_DESCRIPTION_REPAIR_BATCH_SIZE", "1000"))

    SOURCES.sum do |source|
      StructuredDescriptionRepairWorker.new.perform(source, Integer(limit))
    end
  end
end
