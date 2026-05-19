class CrawlRun < ApplicationRecord
  belongs_to :job_source

  STATUSES = %w[running succeeded failed].freeze

  validates :status, inclusion: { in: STATUSES }
end

