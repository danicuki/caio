require_relative "base"
require "uri"

module Crawler
  module Sources
    class HimalayasSearch < Base
      QUERIES = %w[
        software engineer developer backend frontend full-stack react node python ruby rails
        java golang rust elixir data engineer data scientist machine learning ai product manager
        designer devops sre security mobile android ios qa sales customer success marketing
      ].freeze

      COUNTRIES = %w[
        remote united-states canada brazil mexico argentina colombia chile portugal spain
        united-kingdom germany france netherlands ireland india singapore australia
      ].freeze

      def fetch
        queries.flat_map do |query|
          countries.flat_map do |country|
            fetch_query(query, country)
          end
        end.uniq { |job| job.fetch(:source_key) }
      end

      private

      def queries
        ENV.fetch("HIMALAYAS_SEARCH_QUERIES", QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def countries
        ENV.fetch("HIMALAYAS_SEARCH_COUNTRIES", COUNTRIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def fetch_query(query, country)
        limit = 20
        max_pages = Integer(ENV.fetch("MAX_HIMALAYAS_SEARCH_PAGES_PER_QUERY", "2"))
        jobs = []
        total_count = nil

        (0...max_pages).each do |page|
          offset = page * limit
          params = { "q" => query, "limit" => limit, "offset" => offset }
          params["country"] = country if country != "remote"
          params["remote"] = "true" if country == "remote"

          begin
            payload = client.get_json("#{source.base_url}?#{URI.encode_www_form(params)}")
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

        jobs.map { |job| normalize(job) }
      end

      def normalize(job)
        salary = [job["currency"], job["minSalary"], job["maxSalary"]].compact.join(" ")
        locations = Array(job["locationRestrictions"]).map { |location| location.is_a?(Hash) ? location["name"] : location.to_s }

        compact_record(
          source_key: job.fetch("guid").to_s,
          title: job.fetch("title"),
          company: job["companyName"],
          location: locations.empty? ? "Worldwide" : locations.join(", "),
          remote: job.to_s.match?(/remote/i) || locations.any? { |location| location.match?(/remote/i) },
          employment_type: job["employmentType"],
          category: Array(job["categories"]).join(", "),
          salary: salary.empty? ? nil : salary,
          source_url: job.fetch("applicationLink"),
          published_at: parse_time(job["pubDate"]),
          tags_json: raw_json(Array(job["parentCategories"]) + Array(job["seniority"])),
          description: job["description"] || job["excerpt"],
          raw_json: raw_json(job)
        )
      end
    end
  end
end
