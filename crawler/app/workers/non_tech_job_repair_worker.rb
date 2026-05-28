require Rails.root.join("lib/standalone/job_quality")

class NonTechJobRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :job_writes, retry: 2

  def perform(limit = 10_000, start_after_id = 0)
    limit = Integer(limit)
    start_after_id = Integer(start_after_id)
    cutoff = Integer(ENV.fetch("TECH_JOB_MIN_SCORE", "3"))
    deleted = 0
    checked = 0
    last_id = start_after_id

    JobPost.where("id > ?", start_after_id).order(id: :asc).limit(limit).find_each(batch_size: 250) do |post|
      checked += 1
      last_id = post.id
      next if Standalone::JobQuality.score(post, source_name: post.source) >= cutoff

      post.destroy!
      deleted += 1
    end

    Rails.logger.info(
      "non-tech repair start_after_id=#{start_after_id} checked=#{checked} deleted=#{deleted} cutoff=#{cutoff}"
    )

    self.class.perform_async(limit, last_id) if checked == limit
  end
end
