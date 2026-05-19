namespace :crawler do
  desc "Fetch every enabled source once"
  task crawl_all: :environment do
    JobSource.enabled.find_each do |source|
      CrawlSourceWorker.new.perform(source.id)
    end

    puts "Imported #{JobPost.count} total jobs"
  end

  desc "Keep crawling enabled sources until TARGET_JOBS is reached"
  task crawl_until_target: :environment do
    target = Integer(ENV.fetch("TARGET_JOBS", "1000000"))
    sleep_seconds = Integer(ENV.fetch("CRAWL_LOOP_SLEEP_SECONDS", "900"))

    until JobPost.count >= target
      Rake::Task["crawler:crawl_all"].invoke
      Rake::Task["crawler:crawl_all"].reenable
      break if JobPost.count >= target

      sleep sleep_seconds
    end

    puts "Target reached: #{JobPost.count}/#{target}"
  end
end

