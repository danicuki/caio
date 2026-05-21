class Web3careerDescriptionBackfillWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform(limit = nil)
    limit ||= Integer(ENV.fetch("WEB3CAREER_DETAIL_BACKFILL_BATCH_SIZE", "200"))
    state = SourceState.find_or_initialize_by(source: "web3career_description_cursor")
    cursor = state.next_cursor.to_i

    posts = next_posts(cursor, Integer(limit))
    if posts.empty? && cursor.positive?
      cursor = 0
      posts = next_posts(cursor, Integer(limit))
    end

    posts.each { |post| Web3careerDescriptionWorker.perform_async(post.id) }

    state.next_cursor = posts.last&.id.to_i.to_s
    state.exhausted = posts.empty?
    state.last_error = nil
    state.updated_at = Time.current
    state.save!
  end

  private

  def next_posts(cursor, limit)
    JobPost
      .where(source: "web3career")
      .where("id > ?", cursor)
      .where("description IS NULL OR trim(description) = ''")
      .order(:id)
      .limit(limit)
  end
end
