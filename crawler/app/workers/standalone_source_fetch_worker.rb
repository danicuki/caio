require Rails.root.join("lib/standalone/job_api_batch")

class StandaloneSourceFetchWorker
  include Sidekiq::Job

  sidekiq_options queue: :source_fetchers, retry: 5

  def perform(source_name, params = {})
    params = params.with_indifferent_access
    jobs = fetch(source_name, params)
    JobPostImportWorker.enqueue(source_name, jobs)
  end

  private

  def fetch(source_name, params)
    case source_name
    when "remotive"
      Standalone::Sources::Remotive.new.fetch
    when "remoteok"
      Standalone::Sources::RemoteOk.new.fetch
    when "jobicy"
      Standalone::Sources::Jobicy.new.send(:fetch_query, params[:query])
    when "web3career"
      fetch_web3career(params)
    when "arbeitnow"
      Standalone::Sources::Arbeitnow.new.send(:fetch_pages, start_page: Integer(params.fetch(:page)), max_pages: 1).fetch(:jobs)
    when "themuse"
      category = params[:category]
      category = nil if category.to_s.empty?
      Standalone::Sources::TheMuse.new.send(:fetch_pages, start_page: Integer(params.fetch(:page)), max_pages: 1, category: category).fetch(:jobs)
    when "remotejobs"
      Standalone::Sources::RemoteJobs.new.send(:fetch_pages, offset: Integer(params.fetch(:offset)), max_pages: 1).fetch(:jobs)
    when "himalayas"
      Standalone::Sources::Himalayas.new.send(:fetch_pages, offset: Integer(params.fetch(:offset)), max_pages: 1).fetch(:jobs)
    when "himalayas_search"
      fetch_himalayas_search(params)
    when "getonbrd"
      query = params[:query].presence || "software engineer"
      page = Integer(params.fetch(:page, 1))
      Standalone::Sources::GetOnBoard.new.fetch_query(query: query, page: page, max_pages: 1)
    when "greenhouse"
      source = Standalone::Sources::Greenhouse.new
      board = params.fetch(:board)
      payload = source.send(:client).get_json("https://boards-api.greenhouse.io/v1/boards/#{board}/jobs?content=true")
      payload.fetch("jobs", []).map { |job| source.send(:normalize, board, job) }
    when "lever"
      source = Standalone::Sources::Lever.new
      company = params.fetch(:company)
      payload = source.send(:client).get_json("https://api.lever.co/v0/postings/#{company}?mode=json")
      Array(payload).map { |job| source.send(:normalize, company, job) }
    when "ashby"
      source = Standalone::Sources::Ashby.new
      org = params.fetch(:org)
      payload = source.send(:client).get_json("https://api.ashbyhq.com/posting-api/job-board/#{org}")
      Array(payload["jobs"]).map { |job| source.send(:normalize, org, job) }
    when "smartrecruiters"
      fetch_smartrecruiters(params.fetch(:company), Integer(params.fetch(:offset, 0)))
    when "recruitee"
      fetch_recruitee(params.fetch(:company))
    when "workable"
      fetch_workable(params.fetch(:account))
    else
      raise ArgumentError, "Unknown standalone source #{source_name.inspect}"
    end
  rescue StandardError => e
    warn "source_fetch failed source=#{source_name.inspect} params=#{params.inspect}: #{e.class}: #{e.message}"
    []
  end

  def fetch_smartrecruiters(company, offset)
    url = "https://api.smartrecruiters.com/v1/companies/#{company}/postings?limit=100&offset=#{offset}"
    payload = http_client.get_json(url)
    postings = Array(payload["content"])

    detail_limit = Integer(ENV.fetch("SMARTRECRUITERS_DETAILS_PER_PAGE", "25"))

    postings.each_with_index.map do |job, index|
      detail = index < detail_limit ? smartrecruiters_detail(company, job["id"]) : {}
      location = job["location"]
      location = detail["location"] if detail["location"].is_a?(Hash)
      location_text = location.is_a?(Hash) ? [location["fullLocation"], location["city"], location["region"], location["country"]].compact.find(&:present?) : nil
      {
        source_key: "#{company}:#{job.fetch("id")}",
        title: detail["name"] || job.fetch("name"),
        company: detail.dig("company", "name") || company,
        location: location_text,
        remote: location.to_s.match?(/remote/i) || detail.to_s.match?(/remote/i) ? true : nil,
        employment_type: detail.dig("typeOfEmployment", "label") || job.dig("typeOfEmployment", "label"),
        category: detail.dig("function", "label") || job.dig("function", "label"),
        source_url: detail["postingUrl"] || detail["applyUrl"] || job["ref"] || job["applyUrl"] || "https://jobs.smartrecruiters.com/#{company}/#{job["id"]}",
        published_at: parse_time(detail["releasedDate"] || job["releasedDate"]),
        tags: [detail.dig("function", "label"), detail.dig("industry", "label"), job.dig("function", "label"), job.dig("industry", "label")].compact.uniq,
        description: smartrecruiters_description(detail),
        raw: job.merge(detail).merge("smartrecruiters_company" => company)
      }
    end
  end

  def fetch_web3career(params)
    source = Standalone::Sources::Web3Career.new
    mode = params.fetch(:mode, "api")

    case mode
    when "api"
      query = {}
      query["tag"] = params[:tag] if params[:tag].present?
      query["country"] = params[:country] if params[:country].present?
      source.fetch_api_query(query.empty? ? nil : query)
    when "html"
      source.fetch_html_page(Integer(params.fetch(:page)))
    else
      raise ArgumentError, "Unknown web3career mode #{mode.inspect}"
    end
  end

  def fetch_himalayas_search(params)
    query = params[:query].presence || "software engineer"
    country = params[:country].presence
    offset = Integer(params.fetch(:offset, 0))

    Standalone::Sources::HimalayasSearch.new.fetch_query(q: query, country: country, offset: offset, max_pages: 1).fetch(:jobs)
  end

  def smartrecruiters_detail(company, id)
    return {} if id.blank?
    return {} unless ENV.fetch("SMARTRECRUITERS_FETCH_DETAILS", "true") == "true"

    http_client.get_json("https://api.smartrecruiters.com/v1/companies/#{company}/postings/#{id}")
  rescue StandardError => e
    warn "smartrecruiters detail failed company=#{company.inspect} id=#{id.inspect}: #{e.class}: #{e.message}"
    {}
  end

  def smartrecruiters_description(detail)
    sections = detail.dig("jobAd", "sections")
    return nil unless sections.is_a?(Hash)

    sections.values.filter_map do |section|
      text = section["text"].to_s.strip
      next if text.empty?

      title = section["title"].to_s.strip
      title.empty? ? text : "<h3>#{escape_html(title)}</h3>#{text}"
    end.join("\n")
  end

  def fetch_recruitee(company)
    payload = http_client.get_json("https://#{company}.recruitee.com/api/offers/")
    offers = Array(payload["offers"])

    offers.map do |job|
      location = job["location"]
      location_text = location.is_a?(Hash) ? [location["city"], location["state"], location["country"]].compact.join(", ") : location.to_s
      {
        source_key: "#{company}:#{job.fetch("id")}",
        title: job.fetch("title"),
        company: company,
        location: location_text,
        remote: job.to_s.match?(/remote/i) ? true : nil,
        employment_type: job["employment_type"],
        category: job["department"],
        source_url: job["careers_url"] || job["url"] || "https://#{company}.recruitee.com/o/#{job["slug"]}",
        published_at: parse_time(job["published_at"] || job["created_at"]),
        tags: [job["department"], job["employment_type"]].compact,
        description: strip_html(job["description"] || job["requirements"]),
        raw: job.merge("recruitee_company" => company)
      }
    end
  end

  def fetch_workable(account)
    payload = http_client.get_json("https://apply.workable.com/api/v1/widget/accounts/#{account}?details=true")
    jobs = Array(payload["results"] || payload["jobs"])

    jobs.map do |job|
      location = job["location"]
      location_text = location.is_a?(Hash) ? [location["city"], location["region"], location["country"]].compact.join(", ") : location.to_s
      shortcode = job["shortcode"] || job["id"]
      {
        source_key: "#{account}:#{shortcode}",
        title: job.fetch("title"),
        company: account,
        location: location_text,
        remote: job.to_s.match?(/remote/i) ? true : nil,
        employment_type: job["employment_type"],
        category: job["department"],
        source_url: job["url"] || "https://apply.workable.com/#{account}/j/#{shortcode}/",
        published_at: parse_time(job["published_at"] || job["created_at"]),
        tags: [job["department"], job["employment_type"]].compact,
        description: strip_html(job["description"]),
        raw: job.merge("workable_account" => account)
      }
    end
  end

  def http_client
    @http_client ||= Standalone::HttpClient.new
  end

  def parse_time(value)
    return nil if value.blank?

    Time.parse(value.to_s).utc.iso8601
  rescue ArgumentError
    nil
  end

  def strip_html(value)
    value.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
  end

  def escape_html(value)
    value.to_s
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
      .gsub('"', "&quot;")
      .gsub("'", "&#39;")
  end
end
