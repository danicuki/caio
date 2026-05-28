require Rails.root.join("lib/standalone/job_api_batch")

class BuiltinDescriptionWorker
  include Sidekiq::Job

  sidekiq_options queue: :source_fetchers, retry: 5

  def perform(job_post_id)
    post = JobPost.find_by(id: job_post_id, source: "builtin")
    return unless post&.source_url.present?

    job = Standalone::Sources::BuiltIn.new.send(:fetch_detail_job, post.source_url)
    description = job&.dig(:description).to_s.strip
    return if description.empty?

    post.update_columns(
      title: job[:title].presence || post.title,
      company: job[:company].presence || post.company,
      location: job[:location].presence || post.location,
      employment_type: job[:employment_type].presence || post.employment_type,
      salary: job[:salary].presence || post.salary,
      published_at: job[:published_at].presence || post.published_at,
      tags_json: JSON.generate(job[:tags] || []),
      description: description,
      raw_json: JSON.generate(job[:raw] || {}),
      updated_at: Time.current
    )
  end
end
