require_relative "base"
require "erb"
require "uri"

module Crawler
  module Sources
    class GetOnBoard < Base
      QUERIES = [
        "software engineer",
        "developer",
        "backend",
        "frontend",
        "full stack",
        "ruby",
        "python",
        "javascript",
        "typescript",
        "react",
        "node",
        "java",
        "golang",
        "data",
        "devops",
        "product manager",
        "designer",
        "qa"
      ].freeze

      def fetch
        queries.flat_map do |query|
          fetch_query(query)
        end.uniq { |job| job.fetch(:source_key) }
      end

      private

      def queries
        ENV.fetch("GETONBRD_QUERIES", QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def fetch_query(query)
        max_pages = Integer(ENV.fetch("MAX_GETONBRD_PAGES_PER_QUERY", "2"))
        jobs = []
        page = 1

        while page <= max_pages
          begin
            payload = client.get_json("#{source.base_url}?#{URI.encode_www_form("query" => query, "page" => page)}")
            page_jobs = Array(payload["data"])
            break if page_jobs.empty?

            jobs.concat(page_jobs)
            total_pages = payload.dig("meta", "total_pages").to_i
            break if total_pages.positive? && page >= total_pages

            page += 1
          rescue RuntimeError
            raise if jobs.empty?

            break
          end
        end

        jobs.map { |job| normalize(job) }
      end

      def normalize(job)
        attributes = job["attributes"] || {}
        salary = salary_text(attributes["min_salary"], attributes["max_salary"])
        url = job.dig("links", "public_url") || "https://www.getonbrd.com/jobs/#{job.fetch("id")}"

        compact_record(
          source_key: job.fetch("id").to_s,
          title: attributes.fetch("title"),
          company: company_name(job, attributes),
          location: location_text(attributes),
          remote: attributes["remote"],
          category: attributes["category_name"],
          salary: salary,
          source_url: url,
          published_at: parse_time(attributes["published_at"]),
          tags_json: raw_json(tags(attributes)),
          description: description_html(attributes),
          raw_json: raw_json(job)
        )
      end

      def company_name(job, attributes)
        value = attributes["company_name"] || attributes.dig("company", "name")
        return value unless value.to_s.empty?

        slug_company(job["id"], attributes["title"])
      end

      def slug_company(id, title)
        tokens = id.to_s.split("-")
        tokens.pop if tokens.last.to_s.match?(/\A[a-z0-9]{4,8}\z/)
        title_tokens = title.to_s.downcase.gsub(/[^[:alnum:]\s]/, " ").split
        title_tokens.each do |token|
          break unless tokens.first == token

          tokens.shift
        end
        tokens.pop while tokens.last.to_s.match?(/\A(remote|remoto|hybrid|hibrido|onsite|presencial|latam|chile|mexico|colombia|peru|argentina|brazil|brasil)\z/i)
        name = tokens.join(" ")
        name.empty? ? nil : name.split.map(&:capitalize).join(" ")
      end

      def location_text(attributes)
        countries = Array(attributes["countries"]).map(&:to_s).reject(&:empty?)
        return countries.join(", ") unless countries.empty?
        return "Remote" if attributes["remote"]

        attributes["remote_modality"].to_s.presence
      end

      def salary_text(min, max)
        values = [min, max].compact
        return nil if values.empty?

        "USD #{values.uniq.join(" - ")} / month"
      end

      def tags(attributes)
        [
          attributes["category_name"],
          attributes["remote_modality"],
          attributes["lang"],
          Array(attributes["perks"])
        ].flatten.compact.reject(&:empty?).uniq
      end

      def description_html(attributes)
        sections = [
          [attributes["description_headline"], attributes["description"]],
          ["Projects", attributes["projects"]],
          [attributes["functions_headline"], attributes["functions"]],
          [attributes["benefits_headline"], attributes["benefits"]],
          [attributes["desirable_headline"], attributes["desirable"]]
        ]

        sections.filter_map do |heading, body|
          body = body.to_s.strip
          next if body.empty?

          heading = heading.to_s.strip
          heading.empty? ? body : "<h3>#{ERB::Util.html_escape(heading)}</h3>#{body}"
        end.join("\n")
      end
    end
  end
end
