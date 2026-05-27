require_relative "boot"

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module TechJobsCrawler
  class Application < Rails::Application
    config.load_defaults 8.1
    config.active_job.queue_adapter = :sidekiq
    config.time_zone = "UTC"
    config.active_record.dump_schema_after_migration = false
  end
end
