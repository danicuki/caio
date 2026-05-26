require_relative "sources/remotive"
require_relative "sources/arbeitnow"
require_relative "sources/the_muse"
require_relative "sources/remote_ok"
require_relative "sources/remote_jobs"
require_relative "sources/himalayas"
require_relative "sources/himalayas_search"
require_relative "sources/get_on_board"

module Crawler
  class SourceRegistry
    ADAPTERS = {
      "remotive" => Sources::Remotive,
      "arbeitnow" => Sources::Arbeitnow,
      "themuse" => Sources::TheMuse,
      "remoteok" => Sources::RemoteOk,
      "remotejobs" => Sources::RemoteJobs,
      "himalayas" => Sources::Himalayas,
      "himalayas_search" => Sources::HimalayasSearch,
      "getonbrd" => Sources::GetOnBoard
    }.freeze

    def self.build(source)
      ADAPTERS.fetch(source.adapter).new(source)
    end
  end
end
