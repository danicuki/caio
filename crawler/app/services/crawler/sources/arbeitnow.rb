require_relative "base"

module Crawler
  module Sources
    class Arbeitnow < Base
      def fetch
        max_pages = Integer(ENV.fetch("MAX_ARBEITNOW_PAGES", "100"))
        jobs = []

        (1..max_pages).each do |page|
          begin
            payload = client.get_json("#{source.base_url}?page=#{page}")
            page_jobs = payload.fetch("data", [])
            break if page_jobs.empty?

            jobs.concat(page_jobs)
            break unless payload.dig("links", "next")
          rescue RuntimeError
            raise if jobs.empty?

            break
          end
        end

        jobs.map do |job|
          compact_record(
            source_key: (job["slug"] || job["url"] || job["title"]).to_s,
            title: job.fetch("title"),
            company: job["company_name"],
            location: job["location"],
            remote: job["remote"],
            source_url: job["url"],
            published_at: parse_time(job["created_at"]),
            tags_json: raw_json(job["tags"] || []),
            description: job["description"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end
