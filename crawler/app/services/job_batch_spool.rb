require "fileutils"
require "json"
require "securerandom"

class JobBatchSpool
  ROOT = Rails.root.join("tmp/job_batches")

  def self.write(source, jobs)
    FileUtils.mkdir_p(ROOT)

    path = ROOT.join("#{Time.now.utc.strftime("%Y%m%d%H%M%S")}-#{source}-#{SecureRandom.hex(12)}.json")
    File.write(path, JSON.generate(jobs))

    { "spool_path" => path.to_s }
  end

  def self.read(payload)
    case payload
    when Hash
      path = payload.fetch("spool_path")
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
end
