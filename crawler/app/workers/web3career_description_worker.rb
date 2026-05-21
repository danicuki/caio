require Rails.root.join("lib/standalone/job_api_batch")

class Web3careerDescriptionWorker
  include Sidekiq::Job

  sidekiq_options queue: :web3_details, retry: 5

  sidekiq_retry_in do |count, _exception, _jobhash|
    Integer(ENV.fetch("WEB3CAREER_DETAIL_RETRY_SECONDS", "600")) + (count * 300) + rand(120)
  end

  def perform(job_post_id)
    post = JobPost.find_by(id: job_post_id, source: "web3career")
    return unless post
    return if post.description.present?
    return if post.source_url.blank?

    sleep(Float(ENV.fetch("WEB3CAREER_DETAIL_SLEEP_SECONDS", "1.0")))

    description = Standalone::Sources::Web3Career.new.fetch_detail_description(post.source_url)
    return if description.blank?

    post.update_columns(description: description, updated_at: Time.current)
  end
end
