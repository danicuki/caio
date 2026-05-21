require "digest"
require "json"
require "net/http"
require "time"
require "uri"

module Standalone
  module JobQuality
    module_function

    TECH_SOURCES = %w[
      arbeitnow himalayas jobicy linkedin remotive remotejobs remoteok web3career
    ].freeze

    TECH_TITLE_PATTERNS = [
      /\bsoftware\b/i,
      /\bdeveloper\b/i,
      /\bprogrammer\b/i,
      /\bfrontend\b/i,
      /\bfront[- ]end\b/i,
      /\bbackend\b/i,
      /\bback[- ]end\b/i,
      /\bfull[- ]?stack\b/i,
      /\bdevops\b/i,
      /\bsre\b/i,
      /\bsite reliability\b/i,
      /\bplatform engineer\b/i,
      /\binfrastructure engineer\b/i,
      /\bcloud\b/i,
      /\bkubernetes\b/i,
      /\bdata engineer\b/i,
      /\bdata scientist\b/i,
      /\bmachine learning\b/i,
      /\bml engineer\b/i,
      /\bai engineer\b/i,
      /\bsecurity engineer\b/i,
      /\bapplication security\b/i,
      /\binformation security\b/i,
      /\bsecurity analyst\b/i,
      /\bcybersecurity\b/i,
      /\bqa automation\b/i,
      /\btest automation\b/i,
      /\bmobile engineer\b/i,
      /\bios\b/i,
      /\bandroid\b/i,
      /\bweb engineer\b/i,
      /\bengineering manager\b/i,
      /\bhead of engineering\b/i,
      /\bvp engineering\b/i,
      /\bcto\b/i,
      /\btechnical lead\b/i,
      /\btech lead\b/i,
      /\bproduct manager\b/i,
      /\btechnical product\b/i,
      /\bproduct designer\b/i,
      /\bux\b/i,
      /\bui designer\b/i,
      /\buser experience\b/i,
      /\bsolutions architect\b/i,
      /\bsalesforce\b/i,
      /\bsap\b/i,
      /\boracle\b/i,
      /\bservicenow\b/i
    ].freeze

    TECH_CONTEXT_PATTERNS = [
      /\bsoftware engineering\b/i,
      /\binformation technology\b/i,
      /\btechnology\b/i,
      /\bit\b/i,
      /\bdata science\b/i,
      /\bengineering\b/i,
      /\bproduct\b/i,
      /\bdesign\b/i,
      /\bdeveloper relations\b/i,
      /\bdeveloper experience\b/i,
      /\bweb3\b/i,
      /\bblockchain\b/i,
      /\bcrypto\b/i
    ].freeze

    TECH_DESCRIPTION_PATTERNS = [
      /\b(api|apis|sdk|database|distributed systems|microservices|frontend|backend|full[- ]?stack)\b/i,
      /\b(ruby|rails|elixir|phoenix|python|java|javascript|typescript|react|node|go|golang|rust|c\+\+|c#|\.net)\b/i,
      /\b(aws|gcp|azure|docker|kubernetes|terraform|linux|postgres|mysql|redis|kafka)\b/i,
      /\b(machine learning|artificial intelligence|llm|security|devops|ci\/cd|github)\b/i
    ].freeze

    NON_TECH_TITLE_PATTERNS = [
      /\bplumber\b/i,
      /\belectrician\b/i,
      /\bcarpenter\b/i,
      /\bmechanic\b/i,
      /\bdriver\b/i,
      /\bwarehouse\b/i,
      /\bpicker\b/i,
      /\bpacker\b/i,
      /\bforklift\b/i,
      /\bcashier\b/i,
      /\bbarista\b/i,
      /\bcook\b/i,
      /\bchef\b/i,
      /\bserver\b/i,
      /\bwaiter\b/i,
      /\bcleaner\b/i,
      /\bjanitor\b/i,
      /\bhousekeeper\b/i,
      /\bnurse\b/i,
      /\bphysician\b/i,
      /\bdentist\b/i,
      /\btherapist\b/i,
      /\bteacher\b/i,
      /\btutor\b/i,
      /\bstore manager\b/i,
      /\bretail\b/i,
      /\bfacilities assistant\b/i,
      /\bfacilities manager\b/i,
      /\bconstruction\b/i,
      /\bcivil engineer\b/i,
      /\bmechanical engineer\b/i,
      /\belectrical engineer\b/i,
      /\bmanufacturing engineer\b/i,
      /\bfield service engineer\b/i,
      /\bmaintenance\b/i,
      /\bguard\b/i,
      /\breceptionist\b/i,
      /\badministrative assistant\b/i
    ].freeze

    NON_TECH_CONTEXT_PATTERNS = [
      /\bconstruction\b/i,
      /\bfood service\b/i,
      /\bhealthcare\b/i,
      /\bhospitality\b/i,
      /\bretail\b/i,
      /\btransportation\b/i,
      /\blogistics\b/i,
      /\bmanufacturing\b/i,
      /\bmaintenance\b/i,
      /\bfacilities\b/i,
      /\bmedical\b/i,
      /\bnursing\b/i,
      /\beducation\b/i,
      /\baccounting\b/i,
      /\blegal\b/i,
      /\bgeneral business\b/i
    ].freeze

    def filter(source_name, jobs, classifier: nil)
      return jobs if disabled?

      jobs.select { |job| tech?(job, source_name: source_name, classifier: classifier) }
    end

    def tech?(job, source_name: nil, classifier: nil)
      return true if disabled?

      deterministic_score = score(job, source_name: source_name)
      return false if deterministic_score <= Integer(ENV.fetch("TECH_JOB_HARD_REJECT_SCORE", "-5"))
      return true if deterministic_score >= Integer(ENV.fetch("TECH_JOB_HARD_ACCEPT_SCORE", "5"))

      ai_score = classifier&.score(job, source_name: source_name)
      return ai_score >= Float(ENV.fetch("TECH_JOB_AI_ACCEPT_SCORE", "0.65")) unless ai_score.nil?

      deterministic_score >= Integer(ENV.fetch("TECH_JOB_MIN_SCORE", "3"))
    end

    def score(job, source_name: nil)
      fields = fields_for(job)
      title = fields.fetch(:title)
      category = fields.fetch(:category)
      tags = fields.fetch(:tags)
      description = fields.fetch(:description)

      value = 0
      value += 1 if TECH_SOURCES.include?(source_name.to_s)
      value += 5 if matches_any?(title, TECH_TITLE_PATTERNS)
      value += 3 if matches_any?("#{category} #{tags}", TECH_CONTEXT_PATTERNS)
      value += 2 if matches_any?(description, TECH_DESCRIPTION_PATTERNS)
      value -= 8 if matches_any?(title, NON_TECH_TITLE_PATTERNS)
      value -= 4 if matches_any?("#{category} #{tags}", NON_TECH_CONTEXT_PATTERNS)
      value
    end

    def disabled?
      ENV["DISABLE_TECH_JOB_QUALITY_GATE"].to_s == "1"
    end

    def fields_for(job)
      {
        title: read(job, :title),
        category: read(job, :category),
        tags: tags_text(read(job, :tags) || read(job, :tags_json)),
        description: strip_html(read(job, :description))
      }
    end

    def read(job, key)
      return job.public_send(key) if job.respond_to?(key)
      return job[key] if job.respond_to?(:key?) && job.key?(key)

      string_key = key.to_s
      job[string_key] if job.respond_to?(:key?) && job.key?(string_key)
    end

    def tags_text(value)
      case value
      when Array
        value.join(" ")
      else
        value.to_s
      end
    end

    def strip_html(value)
      value.to_s.gsub(/<[^>]+>/, " ")
    end

    def matches_any?(text, patterns)
      patterns.any? { |pattern| text.to_s.match?(pattern) }
    end

    class AiClassifier
      PROVIDER = "gemini".freeze
      DEFAULT_MODEL = "gemini-2.5-flash-lite".freeze

      def self.enabled?
        ENV["TECH_JOB_AI_CLASSIFIER"].to_s == "1" && ENV["GEMINI_API_KEY"].to_s.strip != ""
      end

      def initialize(db_path)
        @db_path = db_path
        @model = ENV.fetch("TECH_JOB_AI_MODEL", DEFAULT_MODEL)
      end

      def score(job, source_name:)
        fingerprint = fingerprint(job, source_name)
        cached = cached_score(fingerprint)
        return cached unless cached.nil?

        result = classify_with_gemini(job, source_name)
        store(fingerprint, job, source_name, result)
        result.fetch(:score)
      rescue StandardError => e
        warn "AI job classifier failed: #{e.class}: #{e.message}"
        nil
      end

      private

      def classify_with_gemini(job, source_name)
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
        request.body = JSON.generate(gemini_payload(job, source_name))

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          http.request(request)
        end
        raise "Gemini HTTP #{response.code}: #{response.body[0,300]}" unless response.is_a?(Net::HTTPSuccess)

        payload = JSON.parse(response.body)
        text = payload.dig("candidates", 0, "content", "parts", 0, "text").to_s
        parsed = JSON.parse(text)
        {
          score: [[Float(parsed.fetch("score")), 0.0].max, 1.0].min,
          label: parsed["label"].to_s,
          reason: parsed["reason"].to_s[0, 500]
        }
      end

      def gemini_payload(job, source_name)
        {
          contents: [
            {
              role: "user",
              parts: [{ text: prompt(job, source_name) }]
            }
          ],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: 160,
            responseMimeType: "application/json"
          }
        }
      end

      def prompt(job, source_name)
        fields = JobQuality.fields_for(job)
        input = {
          source: source_name,
          title: fields.fetch(:title).to_s[0, 200],
          company: JobQuality.read(job, :company).to_s[0, 160],
          category: fields.fetch(:category).to_s[0, 160],
          tags: fields.fetch(:tags).to_s[0, 300],
          description: fields.fetch(:description).to_s.gsub(/\s+/, " ").strip[0, 2_000]
        }

        <<~PROMPT
          You classify jobs for a technology jobs portal.

          Return JSON only, with this exact shape:
          {"score":0.0,"label":"tech|non_tech|uncertain","reason":"short reason"}

          Score means probability this belongs in a tech jobs marketplace.

          Count as tech:
          - software engineering, web/mobile/backend/frontend/full-stack
          - data engineering, data science, AI/ML, analytics engineering
          - DevOps, SRE, cloud, infrastructure, security/cybersecurity, QA automation
          - product manager, product designer, UX/UI, developer relations, solutions architect for software/technology products
          - technical leadership such as CTO, VP Engineering, Engineering Manager

          Count as non-tech:
          - plumbing, construction trades, retail, hospitality, healthcare, education, manual labor, warehouse, driving, food service
          - civil/mechanical/electrical/manufacturing/field-service/facilities roles unless the job is clearly about software, cloud, data, cybersecurity, or digital products
          - sales, marketing, customer support, finance, HR, legal, or operations unless the role is explicitly technical or product/engineering related

          Job:
          #{JSON.generate(input)}
        PROMPT
      end

      def fingerprint(job, source_name)
        source_key = JobQuality.read(job, :source_key)
        source_url = JobQuality.read(job, :source_url)
        raw = [source_name, source_key, source_url, JobQuality.read(job, :title), JobQuality.read(job, :company)].join("|")
        Digest::SHA256.hexdigest(raw)
      end

      def cached_score(fingerprint)
        row = sqlite.get_first_row(
          "SELECT score FROM job_quality_classifications WHERE fingerprint = ? LIMIT 1",
          fingerprint
        )
        row && Float(row[0])
      end

      def store(fingerprint, job, source_name, result)
        sqlite.execute(
          <<~SQL,
            INSERT INTO job_quality_classifications (
              fingerprint, source, source_key, source_url, title, score, label, reason, provider, model, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(fingerprint) DO UPDATE SET
              score = excluded.score,
              label = excluded.label,
              reason = excluded.reason,
              provider = excluded.provider,
              model = excluded.model,
              created_at = excluded.created_at
          SQL
          fingerprint,
          source_name,
          JobQuality.read(job, :source_key),
          JobQuality.read(job, :source_url),
          JobQuality.read(job, :title),
          result.fetch(:score),
          result.fetch(:label),
          result.fetch(:reason),
          PROVIDER,
          @model,
          Time.now.utc.iso8601
        )
      end

      def sqlite
        @sqlite ||= begin
          require "sqlite3"
          db = SQLite3::Database.new(@db_path)
          db.busy_timeout = Integer(ENV.fetch("SQLITE_BUSY_TIMEOUT_MS", "15000"))
          db
        end
      end
    end
  end
end
