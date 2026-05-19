class SourceState < ApplicationRecord
  self.primary_key = :source

  validates :source, presence: true

  def self.fetch(source)
    find_or_create_by!(source: source) do |state|
      state.exhausted = false
      state.updated_at = Time.current
    end
  end
end

