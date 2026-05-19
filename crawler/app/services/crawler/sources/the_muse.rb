require_relative "base"

module Crawler
  module Sources
    class TheMuse < Base
      def fetch
        max_pages = Integer(ENV.fetch("MAX_THEMUSE_PAGES", "500"))
        jobs = []
        page = 1
        page_count = nil

        while page <= max_pages && (page_count.nil? || page <= page_count)
          begin
            payload = client.get_json("#{source.base_url}?page=#{page}&category=Software%20Engineering")
            page_count ||= payload["page_count"].to_i if payload["page_count"]
            page_jobs = payload.fetch("results", [])
            break if page_jobs.empty?

            jobs.concat(page_jobs)
            page += 1
          rescue RuntimeError
            raise if jobs.empty?

            break
          end
        end

        jobs.map do |job|
          compact_record(
            source_key: job.fetch("id").to_s,
            title: job.fetch("name"),
            company: job.dig("company", "name"),
            location: Array(job["locations"]).map { |location| location["name"] }.join(", "),
            remote: Array(job["locations"]).any? { |location| location["name"].to_s.match?(/remote/i) },
            employment_type: Array(job["levels"]).map { |level| level["name"] }.join(", "),
            category: Array(job["categories"]).map { |category| category["name"] }.join(", "),
            source_url: job.dig("refs", "landing_page"),
            published_at: parse_time(job["publication_date"]),
            tags_json: raw_json(job["tags"] || []),
            description: job["contents"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end
