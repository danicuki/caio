require "fileutils"
require "json"
require "securerandom"

class JobBatchSpool
  class MissingSpoolFile < StandardError; end

  ROOT = Rails.root.join("tmp/job_batches")
  LAST_CLEANUP_PATH = ROOT.join(".last_cleanup")
  DEFAULT_TTL_SECONDS = 24 * 60 * 60
  DEFAULT_CLEANUP_INTERVAL_SECONDS = 10 * 60
  DEFAULT_EMERGENCY_TTL_SECONDS = 60 * 60

  def self.write(source, jobs)
    FileUtils.mkdir_p(ROOT)
    path = ROOT.join("#{Time.now.utc.strftime("%Y%m%d%H%M%S")}-#{source}-#{SecureRandom.hex(12)}.json")

    cleanup_old_files_if_due

    File.write(path, JSON.generate(jobs))

    { "spool_path" => path.to_s }
  rescue Errno::ENOSPC
    cleanup_old_files!(ttl_seconds: emergency_ttl_seconds)
    File.write(path, JSON.generate(jobs))
    { "spool_path" => path.to_s }
  end

  def self.read(payload)
    case payload
    when Hash
      path = payload.fetch("spool_path")
      raise MissingSpoolFile, path unless File.exist?(path)

      JSON.parse(File.read(path), symbolize_names: true)
    else
      JSON.parse(payload, symbolize_names: true)
    end
  end

  def self.delete(payload)
    return unless payload.is_a?(Hash)

    path = payload["spool_path"]
    File.delete(path) if path.present? && File.exist?(path)
  end

  def self.cleanup_old_files_if_due
    return unless cleanup_due?

    cleanup_old_files!
  end

  def self.cleanup_old_files!(ttl_seconds: nil)
    ttl_seconds ||= self.ttl_seconds
    FileUtils.mkdir_p(ROOT)
    cutoff = Time.now - ttl_seconds
    deleted = 0
    freed = 0

    Dir.glob(ROOT.join("*.json")).each do |path|
      next unless File.file?(path)
      next unless File.mtime(path) < cutoff

      size = File.size(path)
      File.delete(path)
      deleted += 1
      freed += size
    rescue Errno::ENOENT
      next
    end

    begin
      FileUtils.touch(LAST_CLEANUP_PATH)
    rescue Errno::ENOSPC
      nil
    end

    { deleted: deleted, freed_bytes: freed }
  end

  def self.cleanup_due?
    return true unless File.exist?(LAST_CLEANUP_PATH)

    File.mtime(LAST_CLEANUP_PATH) < Time.now - cleanup_interval_seconds
  end

  def self.ttl_seconds
    Integer(ENV.fetch("JOB_BATCH_SPOOL_TTL_SECONDS", DEFAULT_TTL_SECONDS.to_s))
  rescue ArgumentError
    DEFAULT_TTL_SECONDS
  end

  def self.cleanup_interval_seconds
    Integer(
      ENV.fetch("JOB_BATCH_SPOOL_CLEANUP_INTERVAL_SECONDS", DEFAULT_CLEANUP_INTERVAL_SECONDS.to_s)
    )
  rescue ArgumentError
    DEFAULT_CLEANUP_INTERVAL_SECONDS
  end

  def self.emergency_ttl_seconds
    Integer(ENV.fetch("JOB_BATCH_SPOOL_EMERGENCY_TTL_SECONDS", DEFAULT_EMERGENCY_TTL_SECONDS.to_s))
  rescue ArgumentError
    DEFAULT_EMERGENCY_TTL_SECONDS
  end
end
