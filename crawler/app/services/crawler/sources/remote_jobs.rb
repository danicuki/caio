require_relative "base"

module Crawler
  module Sources
    class RemoteJobs < Base
      def fetch
        limit = 50
        max_pages = Integer(ENV.fetch("MAX_REMOTEJOBS_PAGES", "50"))
        jobs = []

        (0...max_pages).each do |page|
          offset = page * limit
          payload = client.get_json("#{source.base_url}?category=programming&limit=#{limit}&offset=#{offset}")
          page_jobs = payload.fetch("data", [])
          break if page_jobs.empty?

          jobs.concat(page_jobs)
          break unless payload.dig("pagination", "has_more")
        end

        jobs.map do |job|
          compact_record(
            source_key: job.fetch("id").to_s,
            title: job.fetch("title"),
            company: job.dig("company", "name"),
            location: job["location"],
            remote: true,
            employment_type: job["type"],
            category: job.dig("category", "name"),
            salary: job["salary_text"],
            source_url: job["url"] || job["apply_url"],
            published_at: parse_time(job["posted_at"]),
            tags_json: raw_json([job.dig("category", "slug"), job["original_language"]].compact),
            description: job["description"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end
