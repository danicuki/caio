require "sidekiq/api"

class BuiltinDescriptionBackfillWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform(limit = nil)
    limit ||= Integer(ENV.fetch("BUILTIN_DETAIL_BACKFILL_BATCH_SIZE", "250"))
    state = SourceState.find_or_initialize_by(source: "builtin_description_cursor")
    cursor = state.next_cursor.to_i

    posts = next_posts(cursor, Integer(limit))
    if posts.empty? && cursor.positive?
      cursor = 0
      posts = next_posts(cursor, Integer(limit))
    end

    posts.each { |post| BuiltinDescriptionWorker.perform_async(post.id) }

    state.next_cursor = posts.last&.id.to_i.to_s
    state.exhausted = posts.empty?
    state.last_error = nil
    state.updated_at = Time.current
    state.save!
  rescue StandardError => e
    state&.update!(last_error: "#{e.class}: #{e.message}", updated_at: Time.current)
    raise
  end

  private

  def next_posts(cursor, limit)
    JobPost
      .where(source: "builtin")
      .where("id > ?", cursor)
      .where("source_url LIKE ?", "https://builtin.com/job/%")
      .order(:id)
      .limit(limit)
  end
end
