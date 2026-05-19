class JobSource < ApplicationRecord
  has_many :job_posts, dependent: :destroy
  has_many :crawl_runs, dependent: :destroy

  validates :name, :adapter, :base_url, presence: true
  validates :adapter, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
end

