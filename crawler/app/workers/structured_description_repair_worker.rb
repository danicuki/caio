class StructuredDescriptionRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  def perform(source = nil, limit = nil)
    limit ||= Integer(ENV.fetch("STRUCTURED_DESCRIPTION_REPAIR_BATCH_SIZE", "1000"))
    source = source.presence
    state = SourceState.find_or_initialize_by(source: state_key(source))
    cursor = state.next_cursor.to_i

    posts = next_posts(source, cursor, Integer(limit))
    if posts.empty? && cursor.positive?
      cursor = 0
      posts = next_posts(source, cursor, Integer(limit))
    end

    repaired = repair_posts(posts)

    SourceRun.create!(
      source: run_source(source),
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
      source: run_source(source),
      status: "failed",
      fetched_count: 0,
      imported_count: 0,
      error_message: "#{e.class}: #{e.message}",
      created_at: Time.current
    )
    raise
  end

  private

  def next_posts(source, cursor, limit)
    query =
      JobPost
      .where("id > ?", cursor)
      .where("raw_json LIKE ?", "%<%")
      .where("description IS NULL OR description NOT LIKE ?", "%<%")

    query = query.where(source: source) if source

    query.order(:id).limit(limit)
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

  def state_key(source)
    ["structured_description_repair_cursor", source].compact.join(":")
  end

  def run_source(source)
    ["structured_description_repair", source].compact.join(":")
  end
end
