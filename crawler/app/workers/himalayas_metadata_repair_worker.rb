require Rails.root.join("lib/standalone/job_api_batch")

class HimalayasMetadataRepairWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  SOURCES = %w[himalayas himalayas_search].freeze

  def perform(limit = nil)
    limit ||= Integer(ENV.fetch("HIMALAYAS_METADATA_REPAIR_BATCH_SIZE", "5000"))
    state = SourceState.find_or_initialize_by(source: "himalayas_metadata_repair_cursor")
    cursor = state.next_cursor.to_i

    posts = next_posts(cursor, Integer(limit))
    if posts.empty? && cursor.positive?
      cursor = 0
      posts = next_posts(cursor, Integer(limit))
    end

    repaired = posts.sum { |post| repair_post(post) }

    SourceRun.create!(
      source: "himalayas_metadata_repair",
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
    state&.update!(last_error: "#{e.class}: #{e.message}", updated_at: Time.current)
    raise
  end

  private

  def next_posts(cursor, limit)
    JobPost
      .where(source: SOURCES)
      .where("id > ?", cursor)
      .order(:id)
      .limit(limit)
  end

  def repair_post(post)
    raw = JSON.parse(post.raw_json.to_s)
    normalized = normalizer_for(post.source).send(:normalize, [raw]).first
    return 0 unless normalized

    attrs = {
      category: normalized[:category],
      tags_json: JSON.generate(normalized[:tags] || []),
      updated_at: Time.current
    }

    attrs[:source] = "himalayas" if canonical_source_safe?(post)

    post.update_columns(attrs)
    1
  rescue JSON::ParserError
    0
  end

  def normalizer_for(source)
    source == "himalayas_search" ? Standalone::Sources::HimalayasSearch.new : Standalone::Sources::Himalayas.new
  end

  def canonical_source_safe?(post)
    post.source == "himalayas_search" &&
      !JobPost.where(source: "himalayas", source_key: post.source_key).where.not(id: post.id).exists?
  end
end
