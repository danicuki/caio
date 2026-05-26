require Rails.root.join("lib/standalone/job_api_batch")
require "set"

class SourceFanoutWorker
  include Sidekiq::Job

  sidekiq_options queue: :control, retry: false

  EXTRA_GREENHOUSE_BOARDS = %w[
    1password addepar affirm airbnb akamai algolia amplitude anduril anthropic asana atlassian
    benchling betterup calendly canonical chainalysis checkr cloudflare coinbase databricks datadog
    deepl discord doordashusa duolingo elastic figma flexport grammarly hashicorp hubspot instacart
    lyft mongodb notion nuro okta opentable plaid reddit rippling roblox scaleai shopify snowflake
    stripe toast twilio uber vercel wayfair wix zapier zoom
  ].freeze

  EXTRA_LEVER_COMPANIES = %w[
    15five 1password airbnb anduril anthropic apollo asana benchling bitgo brex calendly canonical
    chainalysis coursera datadog discord docker duckduckgo gitlab grammarly gusto hashicorp intercom
    linear mercury mongodb netlify notion postman reddit replit rippling scaleai segment vercel
    webflow weaveworks zapier
  ].freeze

  EXTRA_ASHBY_ORGS = %w[
    11x 1password airwallex anthropic ashby astral beehiiv bolt buildkite cursor deepl elevenlabs
    fal figma gleen granola harvey huggingface incident io linear modal notion openai perplexity
    polar ramp replit replicate runway scale supabase temporal vercel ycombinator
  ].freeze

  SMARTRECRUITERS_COMPANIES = %w[
    BoschGroup Canva DeliveryHero Dynatrace Freshworks Hootsuite NielsenIQ PublicisGroupe
    SmartRecruiters Square Visa Wolt
  ].freeze

  RECRUITEE_COMPANIES = %w[
    aircall bitrise bunq commercetools hotjar mollie personio pitch sennder sonarsource truelayer
  ].freeze

  WORKABLE_ACCOUNTS = %w[
    aircall canonical celery dataiku deepl elastic farfetch grammarly hotjar intercom mollie oyster
    typeform workable
  ].freeze

  HIMALAYAS_SEARCH_QUERIES = Standalone::Sources::HimalayasSearch::QUERIES.freeze
  HIMALAYAS_SEARCH_COUNTRIES = Standalone::Sources::HimalayasSearch::COUNTRIES.freeze
  GETONBRD_QUERIES = Standalone::Sources::GetOnBoard::QUERIES.freeze

  def perform
    enqueue_static_sources
    enqueue_jobicy
    enqueue_web3career
    enqueue_public_marketplaces
    enqueue_company_boards
    enqueue_company_name_ats_probes
    enqueue_new_ats_sources
    enqueue_paged_sources
  end

  private

  def enqueue_static_sources
    %w[remotive remoteok].each do |source|
      StandaloneSourceFetchWorker.perform_async(source, {})
    end
  end

  def enqueue_jobicy
    StandaloneSourceFetchWorker.perform_async("jobicy", {})

    (Standalone::Sources::Jobicy::INDUSTRIES + Standalone::Sources::Jobicy::TAGS).uniq.each do |value|
      key = Standalone::Sources::Jobicy::INDUSTRIES.include?(value) ? "industry" : "tag"
      StandaloneSourceFetchWorker.perform_async("jobicy", { key => value })
    end
  end

  def enqueue_web3career
    StandaloneSourceFetchWorker.perform_async("web3career", { "mode" => "api" })

    Standalone::Sources::Web3Career::TAGS.each do |tag|
      StandaloneSourceFetchWorker.perform_async("web3career", { "mode" => "api", "tag" => tag })
    end

    Standalone::Sources::Web3Career::COUNTRIES.each do |country|
      StandaloneSourceFetchWorker.perform_async("web3career", { "mode" => "api", "country" => country })
    end

    Integer(ENV.fetch("WEB3CAREER_SOURCE_PAGES", "5000")).times do |index|
      StandaloneSourceFetchWorker.perform_async("web3career", { "mode" => "html", "page" => index + 1 })
    end
  end

  def enqueue_public_marketplaces
    himalayas_search_queries.each do |query|
      himalayas_search_countries.each do |country|
        Integer(ENV.fetch("HIMALAYAS_SEARCH_SOURCE_PAGES", "10")).times do |index|
          StandaloneSourceFetchWorker.perform_async("himalayas_search", { "query" => query, "country" => country, "offset" => index * 20 })
        end
      end
    end

    getonbrd_queries.each do |query|
      Integer(ENV.fetch("GETONBRD_SOURCE_PAGES", "2")).times do |index|
        StandaloneSourceFetchWorker.perform_async("getonbrd", { "query" => query, "page" => index + 1 })
      end
    end
  end

  def enqueue_company_boards
    greenhouse_boards.each do |board|
      StandaloneSourceFetchWorker.perform_async("greenhouse", { "board" => board })
    end

    lever_companies.each do |company|
      StandaloneSourceFetchWorker.perform_async("lever", { "company" => company })
    end

    ashby_orgs.each do |org|
      StandaloneSourceFetchWorker.perform_async("ashby", { "org" => org })
    end
  end

  def enqueue_new_ats_sources
    smartrecruiters_companies.each do |company|
      Integer(ENV.fetch("SMARTRECRUITERS_SOURCE_PAGES", "60")).times do |index|
        StandaloneSourceFetchWorker.perform_async("smartrecruiters", { "company" => company, "offset" => index * 100 })
      end
    end

    recruitee_companies.each do |company|
      StandaloneSourceFetchWorker.perform_async("recruitee", { "company" => company })
    end

    workable_accounts.each do |account|
      StandaloneSourceFetchWorker.perform_async("workable", { "account" => account })
    end
  end

  def enqueue_company_name_ats_probes
    candidates = company_name_candidates
    return if candidates.empty?

    limit = Integer(ENV.fetch("ATS_PROBE_COMPANIES_PER_RUN", "150"))
    state = SourceState.find_or_initialize_by(source: "ats_probe_company_cursor")
    cursor = state.next_cursor.to_i
    window = candidates.rotate(cursor).first(limit)

    window.each do |candidate|
      enqueue_ats_probe_candidate(candidate)
    end

    state.next_cursor = ((cursor + window.length) % candidates.length).to_s
    state.exhausted = false
    state.last_error = nil
    state.updated_at = Time.current
    state.save!
  end

  def enqueue_paged_sources
    Integer(ENV.fetch("ARBEITNOW_SOURCE_PAGES", "250")).times do |index|
      StandaloneSourceFetchWorker.perform_async("arbeitnow", { "page" => index + 1 })
    end

    Standalone::Sources::TheMuse::CATEGORIES.each do |category|
      Integer(ENV.fetch("THEMUSE_SOURCE_PAGES_PER_CATEGORY", "100")).times do |index|
        StandaloneSourceFetchWorker.perform_async("themuse", { "category" => category, "page" => index + 1 })
      end
    end

    Integer(ENV.fetch("REMOTEJOBS_SOURCE_PAGES", "300")).times do |index|
      StandaloneSourceFetchWorker.perform_async("remotejobs", { "offset" => index * 50 })
    end

    Integer(ENV.fetch("HIMALAYAS_SOURCE_PAGES", "500")).times do |index|
      StandaloneSourceFetchWorker.perform_async("himalayas", { "offset" => index * 20 })
    end
  end

  def enqueue_ats_probe_candidate(candidate)
    slug = candidate.fetch(:slug)
    compact = candidate.fetch(:compact)
    camel = candidate.fetch(:camel)

    StandaloneSourceFetchWorker.perform_async("greenhouse", { "board" => slug })
    StandaloneSourceFetchWorker.perform_async("lever", { "company" => slug })
    StandaloneSourceFetchWorker.perform_async("ashby", { "org" => slug })
    StandaloneSourceFetchWorker.perform_async("recruitee", { "company" => slug })
    StandaloneSourceFetchWorker.perform_async("workable", { "account" => slug })
    StandaloneSourceFetchWorker.perform_async("smartrecruiters", { "company" => compact, "offset" => 0 })
    StandaloneSourceFetchWorker.perform_async("smartrecruiters", { "company" => camel, "offset" => 0 }) if camel != compact
  end

  def company_name_candidates
    JobPost
      .where.not(company: nil)
      .group(:company)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(Integer(ENV.fetch("ATS_PROBE_COMPANY_POOL", "5000")))
      .count
      .keys
      .filter_map { |company| company_candidate(company) }
      .uniq { |candidate| candidate[:slug] }
      .reject { |candidate| known_candidate_slug?(candidate[:slug]) }
  end

  def company_candidate(company)
    clean = company.to_s
      .gsub(/\b(inc|incorporated|llc|ltd|limited|gmbh|ag|sa|s\.a\.|plc|corp|corporation|co|company)\b\.?/i, " ")
      .gsub(/[^[:alnum:]\s]/, " ")
      .gsub(/\s+/, " ")
      .strip
    return nil if clean.length < 3

    words = clean.split
    slug = words.join("-").downcase
    compact = words.join
    camel = words.map { |word| word[0].to_s.upcase + word[1..].to_s.downcase }.join
    { slug: slug, compact: compact, camel: camel }
  end

  def known_candidate_slug?(slug)
    static_slugs.include?(slug)
  end

  def static_slugs
    @static_slugs ||= (
      greenhouse_boards +
      lever_companies +
      ashby_orgs +
      recruitee_companies +
      workable_accounts +
      smartrecruiters_companies.map(&:downcase)
    ).map(&:downcase).to_set
  end

  def greenhouse_boards
    (Standalone::Sources::Greenhouse::DEFAULT_BOARDS + EXTRA_GREENHOUSE_BOARDS + discovered(%r{boards(?:-api)?\.greenhouse\.io/(?:v1/boards/)?([^/?#]+)}i)).uniq
  end

  def lever_companies
    (Standalone::Sources::Lever::DEFAULT_COMPANIES + EXTRA_LEVER_COMPANIES + discovered(%r{jobs\.lever\.co/([^/?#]+)}i)).uniq
  end

  def ashby_orgs
    (Standalone::Sources::Ashby::DEFAULT_ORGS + EXTRA_ASHBY_ORGS + discovered(%r{jobs\.ashbyhq\.com/([^/?#]+)}i)).uniq
  end

  def smartrecruiters_companies
    SMARTRECRUITERS_COMPANIES + discovered(%r{jobs\.smartrecruiters\.com/([^/?#]+)}i)
  end

  def recruitee_companies
    RECRUITEE_COMPANIES + discovered(%r{https?://([^./]+)\.recruitee\.com}i)
  end

  def workable_accounts
    WORKABLE_ACCOUNTS + discovered(%r{apply\.workable\.com/([^/?#]+)}i)
  end

  def himalayas_search_queries
    ENV.fetch("HIMALAYAS_SEARCH_QUERIES", HIMALAYAS_SEARCH_QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
  end

  def himalayas_search_countries
    ENV.fetch("HIMALAYAS_SEARCH_COUNTRIES", HIMALAYAS_SEARCH_COUNTRIES.join(",")).split(",").map(&:strip).reject(&:empty?)
  end

  def getonbrd_queries
    ENV.fetch("GETONBRD_QUERIES", GETONBRD_QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
  end

  def discovered(pattern)
    JobPost.where.not(source_url: nil).limit(100_000).pluck(:source_url).filter_map do |url|
      url.to_s[pattern, 1]
    end.map(&:downcase).reject { |slug| slug.empty? || slug == "api" }.uniq
  end
end
