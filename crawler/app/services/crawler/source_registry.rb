require_relative "sources/remotive"
require_relative "sources/arbeitnow"
require_relative "sources/the_muse"
require_relative "sources/remote_ok"
require_relative "sources/remote_jobs"
require_relative "sources/himalayas"

module Crawler
  class SourceRegistry
    ADAPTERS = {
      "remotive" => Sources::Remotive,
      "arbeitnow" => Sources::Arbeitnow,
      "themuse" => Sources::TheMuse,
      "remoteok" => Sources::RemoteOk,
      "remotejobs" => Sources::RemoteJobs,
      "himalayas" => Sources::Himalayas
    }.freeze

    def self.build(source)
      ADAPTERS.fetch(source.adapter).new(source)
    end
  end
end
