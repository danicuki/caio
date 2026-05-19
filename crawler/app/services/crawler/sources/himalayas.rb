require_relative "base"

module Crawler
  module Sources
    class Himalayas < Base
      def fetch
        limit = 20
        max_pages = Integer(ENV.fetch("MAX_HIMALAYAS_PAGES", "500"))
        jobs = []
        total_count = nil

        (0...max_pages).each do |page|
          begin
            offset = page * limit
            payload = client.get_json("#{source.base_url}?limit=#{limit}&offset=#{offset}")
            total_count ||= payload["totalCount"].to_i if payload["totalCount"]
            page_jobs = payload.fetch("jobs", [])
            break if page_jobs.empty?

            jobs.concat(page_jobs)
            break if total_count && offset + limit >= total_count
          rescue RuntimeError
            raise if jobs.empty?

            break
          end
        end

        jobs.map do |job|
          salary = [job["currency"], job["minSalary"], job["maxSalary"]].compact.join(" ")
          locations = Array(job["locationRestrictions"]).map { |location| location["name"] }
          compact_record(
            source_key: job.fetch("guid").to_s,
            title: job.fetch("title"),
            company: job["companyName"],
            location: locations.empty? ? "Worldwide" : locations.join(", "),
            remote: true,
            employment_type: job["employmentType"],
            category: Array(job["categories"]).join(", "),
            salary: salary.empty? ? nil : salary,
            source_url: job.fetch("applicationLink"),
            published_at: parse_time(job["pubDate"]),
            tags_json: raw_json(Array(job["parentCategories"]) + Array(job["seniority"])),
            description: job["description"],
            raw_json: raw_json(job)
          )
        end
      end
    end
  end
end
