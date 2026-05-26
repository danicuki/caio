class ArbeitnowDescriptionRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform(limit = nil)
    limit ||= Integer(ENV.fetch("ARBEITNOW_DESCRIPTION_REPAIR_BATCH_SIZE", "500"))
    state = SourceState.find_or_initialize_by(source: "arbeitnow_description_repair_cursor")
    cursor = state.next_cursor.to_i

    posts = next_posts(cursor, Integer(limit))
    if posts.empty? && cursor.positive?
      cursor = 0
      posts = next_posts(cursor, Integer(limit))
    end

    repaired = repair_posts(posts)

    SourceRun.create!(
      source: "arbeitnow_description_repair",
      status: "succeeded",
      fetched_count: posts.size,
      imported_count: repaired,
      created_at: Time.current
    )

    state.next_cursor = posts.last&.id.to_i.to_s
    state.exhausted = posts.empty?
    state.last_error = nil
    state.updated_at = Time.current
    state.save!

    repaired
  rescue StandardError => e
    SourceRun.create!(
      source: "arbeitnow_description_repair",
      status: "failed",
      fetched_count: 0,
      imported_count: 0,
      error_message: "#{e.class}: #{e.message}",
      created_at: Time.current
    )
    raise
  end

  private

  def next_posts(cursor, limit)
    JobPost
      .where(source: "arbeitnow")
      .where("id > ?", cursor)
      .where("raw_json LIKE ?", "%<%")
      .where("description IS NULL OR description NOT LIKE ?", "%<%")
      .order(:id)
      .limit(limit)
  end

  def repair_posts(posts)
    posts.sum do |post|
      html = raw_description_html(post)
      next 0 unless structured_html?(html)

      post.update_columns(description: html, updated_at: Time.current)
      1
    end
  end

  def raw_description_html(post)
    raw = JSON.parse(post.raw_json.to_s)
    raw["description"].to_s.strip
  rescue JSON::ParserError
    ""
  end

  def structured_html?(html)
    html.match?(/<(p|h2|h3|ul|ol|li|strong|br)\b/i)
  end
end
