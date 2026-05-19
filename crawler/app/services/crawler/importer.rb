module Crawler
  class Importer
    def initialize(source)
      @source = source
    end

    def import(records)
      records.sum do |record|
        post = @source.job_posts.find_or_initialize_by(source_key: record.fetch(:source_key))
        post.assign_attributes(record.except(:source_key))
        post.new_record? || post.changed? ? (post.save! && 1) : 0
      end
    end
  end
end

