require "json"

module Crawler
  module Sources
    class Base
      def initialize(source, client: Crawler::HttpClient.new)
        @source = source
        @client = client
      end

      private

      attr_reader :source, :client

      def raw_json(value)
        JSON.generate(value)
      end

      def parse_time(value)
        return if value.blank?

        return Time.zone.at(value.to_i) if value.is_a?(Numeric)
        return Time.zone.at(value.to_i) if value.to_s.match?(/\A\d{10,}\z/)

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def compact_record(record)
        record.compact
      end
    end
  end
end
