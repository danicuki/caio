require Rails.root.join("lib/standalone/job_api_batch")

class LinkedinDescriptionWorker
  include Sidekiq::Job

  sidekiq_options queue: :linkedin_details, retry: 10

  sidekiq_retry_in do |count, exception, _jobhash|
    if exception.is_a?(Standalone::RateLimited)
      Integer(ENV.fetch("LINKEDIN_DETAIL_RATE_LIMIT_RETRY_SECONDS", "900")) + (count * 300) + rand(180)
    else
      (count + 1) * 120
    end
  end

  def perform(job_post_id)
    post = JobPost.find_by(id: job_post_id, source: "linkedin")
    return unless post
    return if post.description.present?

    sleep(Float(ENV.fetch("LINKEDIN_DETAIL_SLEEP_SECONDS", "1.5")))

    linkedin_id = post.source_key.presence || post.raw_json.to_s[/linkedin_job_id["']?\s*[:=]\s*["']?(\d+)/, 1]
    return if linkedin_id.blank?

    description = Standalone::Sources::LinkedinPublic.new.send(:fetch_detail_description, linkedin_id)
    return if description.blank?

    post.update_columns(description: description, updated_at: Time.current)
  end
end

