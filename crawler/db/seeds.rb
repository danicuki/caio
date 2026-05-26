JobSource.find_or_create_by!(adapter: "remotive") do |source|
  source.name = "Remotive"
  source.base_url = "https://remotive.com/api/remote-jobs"
  source.crawl_interval_minutes = 360
  source.terms_note = "Public API. Link back to Remotive URL, mention Remotive as source, and keep request rate low."
end

JobSource.find_or_create_by!(adapter: "arbeitnow") do |source|
  source.name = "Arbeitnow"
  source.base_url = "https://www.arbeitnow.com/api/job-board-api"
  source.crawl_interval_minutes = 360
end

JobSource.find_or_create_by!(adapter: "themuse") do |source|
  source.name = "The Muse"
  source.base_url = "https://www.themuse.com/api/public/jobs"
  source.crawl_interval_minutes = 360
end

JobSource.find_or_create_by!(adapter: "remoteok") do |source|
  source.name = "Remote OK"
  source.base_url = "https://remoteok.com/api"
  source.crawl_interval_minutes = 360
end

JobSource.find_or_create_by!(adapter: "remotejobs") do |source|
  source.name = "RemoteJobs.org"
  source.base_url = "https://remotejobs.org/api/v1/jobs"
  source.crawl_interval_minutes = 360
  source.terms_note = "Public API. Requests visible Powered by RemoteJobs.org attribution when displaying listings."
end

JobSource.find_or_create_by!(adapter: "himalayas") do |source|
  source.name = "Himalayas"
  source.base_url = "https://himalayas.app/jobs/api"
  source.crawl_interval_minutes = 1440
  source.terms_note = "Free public API. Displayed data requires visible link back to Himalayas and source attribution."
end

JobSource.find_or_create_by!(adapter: "himalayas_search") do |source|
  source.name = "Himalayas Search"
  source.base_url = "https://himalayas.app/jobs/api/search"
  source.crawl_interval_minutes = 1440
  source.terms_note = "Free public API. Query fanout across role and country filters for broader remote job coverage."
end

JobSource.find_or_create_by!(adapter: "getonbrd") do |source|
  source.name = "Get on Board"
  source.base_url = "https://www.getonbrd.com/api/v0/search/jobs"
  source.crawl_interval_minutes = 360
  source.terms_note = "Public API exposes published marketplace jobs without authentication; LATAM tech coverage."
end
