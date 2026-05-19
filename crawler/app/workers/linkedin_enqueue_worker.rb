class LinkedinEnqueueWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: 3

  DEFAULT_BATCH_SIZE = 500
  DEFAULT_MAX_START = 999

  def perform(batch_size = nil)
    batch_size = Integer(batch_size || ENV.fetch("LINKEDIN_ENQUEUE_BATCH_SIZE", DEFAULT_BATCH_SIZE))
    max_start = Integer(ENV.fetch("LINKEDIN_MAX_START", DEFAULT_MAX_START))
    keywords = read_list(ENV.fetch("LINKEDIN_KEYWORDS_FILE", Rails.root.join("data/linkedin_keywords.txt").to_s))
    locations = read_list(ENV.fetch("LINKEDIN_LOCATIONS_FILE", Rails.root.join("data/linkedin_locations_from_db.txt").to_s))
    raise "No LinkedIn keywords loaded" if keywords.empty?
    raise "No LinkedIn locations loaded" if locations.empty?

    state = SourceState.fetch("linkedin_enqueue")
    keyword_index, location_index, start = parse_cursor(state.next_cursor)
    enqueued = 0

    while keyword_index < keywords.length && enqueued < batch_size
      if start > max_start
        start = 0
        location_index += 1
        if location_index >= locations.length
          location_index = 0
          keyword_index += 1
        end
        next
      end

      LinkedinPageWorker.perform_async(keywords[keyword_index], locations[location_index], start)
      enqueued += 1
      start += 25
    end

    exhausted = keyword_index >= keywords.length
    state.update!(
      next_cursor: exhausted ? nil : [keyword_index, location_index, start].join(","),
      exhausted: exhausted,
      last_error: nil,
      updated_at: Time.current
    )

    SourceRun.create!(
      source: "linkedin_enqueue",
      status: "succeeded",
      fetched_count: enqueued,
      imported_count: 0,
      created_at: Time.current
    )

    enqueued
  end

  private

  def read_list(path)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).map(&:strip).reject(&:empty?).uniq
  end

  def parse_cursor(cursor)
    parts = cursor.to_s.split(",").map(&:to_i)
    [parts[0] || 0, parts[1] || 0, parts[2] || 0]
  end
end
