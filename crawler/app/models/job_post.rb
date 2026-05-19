class JobPost < ApplicationRecord
  validates :source_key, :title, :source_url, presence: true
  validates :source_key, uniqueness: { scope: :source }
end
