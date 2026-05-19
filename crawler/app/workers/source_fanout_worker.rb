require Rails.root.join("lib/standalone/job_api_batch")

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

  def perform
    enqueue_static_sources
    enqueue_jobicy
    enqueue_company_boards
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

  def discovered(pattern)
    JobPost.where.not(source_url: nil).limit(100_000).pluck(:source_url).filter_map do |url|
      url.to_s[pattern, 1]
    end.map(&:downcase).reject { |slug| slug.empty? || slug == "api" }.uniq
  end
end
