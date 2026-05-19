require_relative "base"

module Crawler
  module Sources
    class RemoteOk < Base
      def fetch
        payload = client.get_json(source.base_url)
        payload.select { |item| item.is_a?(Hash) && item["id"] }.map do |job|
          compact_record(
            source_key: job.fetch("id").to_s,
            title: job.fetch("position"),
            company: job["company"],
            location: job["location"],
            remote: true,
            employment_type: job["job_type"],
            salary: job["salary"],
            source_url: job["url"] || "https://remoteok.com/remote-jobs/#{job["id"]}",
            published_at: parse_time(job["date"]),
            tags_json: raw_json(job["tags"] || []),
            description: job["description"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end

