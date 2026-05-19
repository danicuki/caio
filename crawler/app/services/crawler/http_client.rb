require "faraday"
require "json"

module Crawler
  class HttpClient
    USER_AGENT = "TechJobsCrawler/0.1 (+local development; contact: jobs@example.invalid)".freeze

    def get_json(url)
      response = connection.get(url)
      raise "HTTP #{response.status} for #{url}" unless response.success?

      JSON.parse(response.body)
    end

    private

    def connection
      @connection ||= Faraday.new do |faraday|
        faraday.headers["User-Agent"] = USER_AGENT
        faraday.headers["Accept"] = "application/json"
        faraday.options.timeout = 30
        faraday.options.open_timeout = 10
      end
    end
  end
end

