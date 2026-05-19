require_relative "base"

module Crawler
  module Sources
    class Remotive < Base
      def fetch
        payload = client.get_json("#{source.base_url}?category=software-dev")
        payload.fetch("jobs", []).map do |job|
          compact_record(
            source_key: job.fetch("id").to_s,
            title: job.fetch("title"),
            company: job["company_name"],
            location: job["candidate_required_location"],
            remote: true,
            employment_type: job["job_type"],
            category: job["category"],
            salary: job["salary"],
            source_url: job["url"],
            published_at: parse_time(job["publication_date"]),
            tags_json: raw_json(job["tags"] || []),
            description: job["description"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end

