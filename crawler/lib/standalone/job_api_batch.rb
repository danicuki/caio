require "csv"
require "cgi"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "open3"
require "shellwords"
require "time"
require "uri"

require_relative "job_quality"

begin
  require "sqlite3"
rescue LoadError
  nil
end

module Standalone
  USER_AGENT = "TechJobsCrawler/0.1 (+local development; contact: jobs@example.invalid)".freeze

  class RateLimited < StandardError; end

  ImportStats = Struct.new(
    :fetched_count,
    :imported_count,
    :inserted_count,
    :updated_count,
    :skipped_count,
    keyword_init: true
  ) do
    def +(other)
      other = ImportStats.from(other)
      ImportStats.new(
        fetched_count: fetched_count.to_i + other.fetched_count.to_i,
        imported_count: imported_count.to_i + other.imported_count.to_i,
        inserted_count: inserted_count.to_i + other.inserted_count.to_i,
        updated_count: updated_count.to_i + other.updated_count.to_i,
        skipped_count: skipped_count.to_i + other.skipped_count.to_i
      )
    end

    def to_i
      imported_count.to_i
    end

    def self.zero
      new(fetched_count: 0, imported_count: 0, inserted_count: 0, updated_count: 0, skipped_count: 0)
    end

    def self.from(value)
      return value if value.is_a?(self)

      new(fetched_count: value.to_i, imported_count: value.to_i, inserted_count: 0, updated_count: value.to_i, skipped_count: 0)
    end
  end

  class Database
    def initialize(path)
      @path = path
      FileUtils.mkdir_p(File.dirname(path))
      create_schema
    end

    def upsert_jobs(source_name, jobs)
      upsert_jobs_with_stats(source_name, jobs).to_i
    end

    def upsert_jobs_with_stats(source_name, jobs)
      fetched_count = jobs.size
      classifier = JobQuality::AiClassifier.new(@path) if JobQuality::AiClassifier.enabled?
      jobs = JobQuality.filter(source_name, jobs, classifier: classifier)
      rejected_count = fetched_count - jobs.size
      warn "quality gate rejected #{rejected_count}/#{fetched_count} #{source_name} jobs" if rejected_count.positive?
      return ImportStats.new(fetched_count: fetched_count, imported_count: 0, inserted_count: 0, updated_count: 0, skipped_count: rejected_count) if jobs.empty?

      if defined?(SQLite3::Database)
        stats = upsert_jobs_native(source_name, jobs)
        stats.fetched_count = fetched_count
        stats.skipped_count = stats.skipped_count.to_i + rejected_count
        return stats
      end

      jobs.each_slice(100) do |batch|
        now = Time.now.utc.iso8601
        sql = +"BEGIN;\n"
        batch.each do |job|
          normalized = Normalizer.normalize(job)
          company_id = company_slug(job[:company])
          sql << <<~SQL
            INSERT INTO job_posts (
              source, source_key, title, company, company_id, location, remote, employment_type,
              category, salary, source_url, published_at, tags_json, description,
              raw_json, salary_min, salary_max, salary_currency, salary_period,
              location_city, location_state, location_country, location_continent,
              location_scope, created_at, updated_at
            ) VALUES (
              #{quote(source_name)}, #{quote(job.fetch(:source_key))}, #{quote(job.fetch(:title))},
              #{quote(job[:company])}, #{quote(company_id)}, #{quote(job[:location])}, #{boolean(job[:remote])},
              #{quote(job[:employment_type])}, #{quote(job[:category])}, #{quote(job[:salary])},
              #{quote(job.fetch(:source_url))}, #{quote(job[:published_at])}, #{quote(JSON.generate(job[:tags] || []))},
              #{quote(job[:description])}, #{quote(JSON.generate(job[:raw]))},
              #{number(normalized[:salary_min])}, #{number(normalized[:salary_max])},
              #{quote(normalized[:salary_currency])}, #{quote(normalized[:salary_period])},
              #{quote(normalized[:location_city])}, #{quote(normalized[:location_state])},
              #{quote(normalized[:location_country])}, #{quote(normalized[:location_continent])},
              #{quote(normalized[:location_scope])}, #{quote(now)}, #{quote(now)}
            )
            ON CONFLICT(source, source_key) DO UPDATE SET
              title = excluded.title,
              company = excluded.company,
              company_id = excluded.company_id,
              location = excluded.location,
              remote = excluded.remote,
              employment_type = excluded.employment_type,
              category = excluded.category,
              salary = excluded.salary,
              published_at = excluded.published_at,
              tags_json = excluded.tags_json,
              description = COALESCE(NULLIF(excluded.description, ''), job_posts.description),
              raw_json = COALESCE(NULLIF(excluded.raw_json, ''), job_posts.raw_json),
              salary_min = excluded.salary_min,
              salary_max = excluded.salary_max,
              salary_currency = excluded.salary_currency,
              salary_period = excluded.salary_period,
              location_city = excluded.location_city,
              location_state = excluded.location_state,
              location_country = excluded.location_country,
              location_continent = excluded.location_continent,
              location_scope = excluded.location_scope,
              updated_at = excluded.updated_at
            ON CONFLICT(source_url) DO UPDATE SET
              title = excluded.title,
              company = excluded.company,
              company_id = excluded.company_id,
              location = excluded.location,
              remote = excluded.remote,
              employment_type = excluded.employment_type,
              category = excluded.category,
              salary = excluded.salary,
              published_at = excluded.published_at,
              tags_json = excluded.tags_json,
              description = COALESCE(NULLIF(excluded.description, ''), job_posts.description),
              raw_json = COALESCE(NULLIF(excluded.raw_json, ''), job_posts.raw_json),
              salary_min = excluded.salary_min,
              salary_max = excluded.salary_max,
              salary_currency = excluded.salary_currency,
              salary_period = excluded.salary_period,
              location_city = excluded.location_city,
              location_state = excluded.location_state,
              location_country = excluded.location_country,
              location_continent = excluded.location_continent,
              location_scope = excluded.location_scope,
              updated_at = excluded.updated_at;
          SQL
        end
        sql << "COMMIT;\n"
        execute(sql)
      end

      ImportStats.new(
        fetched_count: fetched_count,
        imported_count: jobs.size,
        inserted_count: 0,
        updated_count: jobs.size,
        skipped_count: rejected_count
      )
    end

    def upsert_jobs_native(source_name, jobs)
      now = Time.now.utc.iso8601
      inserted_count = 0
      updated_count = 0
      db = SQLite3::Database.new(@path)
      db.busy_timeout = Integer(ENV.fetch("SQLITE_BUSY_TIMEOUT_MS", "15000"))
      db.execute("PRAGMA journal_mode = WAL")
      db.execute("PRAGMA synchronous = NORMAL")
      skipped_count = 0

      sql = <<~SQL
        INSERT INTO job_posts (
          source, source_key, title, company, company_id, location, remote, employment_type,
          category, salary, source_url, published_at, tags_json, description,
          raw_json, salary_min, salary_max, salary_currency, salary_period,
          location_city, location_state, location_country, location_continent,
          location_scope, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ON CONFLICT(source, source_key) DO UPDATE SET
          title = excluded.title,
          company = excluded.company,
          company_id = excluded.company_id,
          location = excluded.location,
          remote = excluded.remote,
          employment_type = excluded.employment_type,
          category = excluded.category,
          salary = excluded.salary,
          published_at = excluded.published_at,
          tags_json = excluded.tags_json,
          description = COALESCE(NULLIF(excluded.description, ''), job_posts.description),
          raw_json = COALESCE(NULLIF(excluded.raw_json, ''), job_posts.raw_json),
          salary_min = excluded.salary_min,
          salary_max = excluded.salary_max,
          salary_currency = excluded.salary_currency,
          salary_period = excluded.salary_period,
          location_city = excluded.location_city,
          location_state = excluded.location_state,
          location_country = excluded.location_country,
          location_continent = excluded.location_continent,
          location_scope = excluded.location_scope,
          updated_at = excluded.updated_at
        ON CONFLICT(source_url) DO UPDATE SET
          title = excluded.title,
          company = excluded.company,
          company_id = excluded.company_id,
          location = excluded.location,
          remote = excluded.remote,
          employment_type = excluded.employment_type,
          category = excluded.category,
          salary = excluded.salary,
          published_at = excluded.published_at,
          tags_json = excluded.tags_json,
          description = COALESCE(NULLIF(excluded.description, ''), job_posts.description),
          raw_json = COALESCE(NULLIF(excluded.raw_json, ''), job_posts.raw_json),
          salary_min = excluded.salary_min,
          salary_max = excluded.salary_max,
          salary_currency = excluded.salary_currency,
          salary_period = excluded.salary_period,
          location_city = excluded.location_city,
          location_state = excluded.location_state,
          location_country = excluded.location_country,
          location_continent = excluded.location_continent,
          location_scope = excluded.location_scope,
          updated_at = excluded.updated_at
      SQL

      update_by_url_sql = <<~SQL
        UPDATE job_posts SET
          title = ?,
          company = ?,
          company_id = ?,
          location = ?,
          remote = ?,
          employment_type = ?,
          category = ?,
          salary = ?,
          published_at = ?,
          tags_json = ?,
          description = COALESCE(NULLIF(?, ''), description),
          raw_json = COALESCE(NULLIF(?, ''), raw_json),
          salary_min = ?,
          salary_max = ?,
          salary_currency = ?,
          salary_period = ?,
          location_city = ?,
          location_state = ?,
          location_country = ?,
          location_continent = ?,
          location_scope = ?,
          updated_at = ?
        WHERE source_url = ?
      SQL

      with_sqlite_busy_retry do
        transaction_inserted_count = 0
        transaction_updated_count = 0
        transaction_skipped_count = 0

        db.transaction do
          statement = db.prepare(sql)
          update_by_url_statement = db.prepare(update_by_url_sql)
          jobs.each do |job|
            normalized = Normalizer.normalize(job)
            source_key = job.fetch(:source_key)
            source_url = job.fetch(:source_url)
            tags_json = JSON.generate(job[:tags] || [])
            raw_json = JSON.generate(job[:raw])
            company_id = company_slug(job[:company])
            incoming = materialized_job_attributes(
              source: source_name,
              source_key: source_key,
              title: job.fetch(:title),
              company: job[:company],
              company_id: company_id,
              location: job[:location],
              remote: native_boolean(job[:remote]),
              employment_type: job[:employment_type],
              category: job[:category],
              salary: job[:salary],
              source_url: source_url,
              published_at: job[:published_at],
              tags_json: tags_json,
              description: job[:description],
              raw_json: raw_json,
              salary_min: normalized[:salary_min],
              salary_max: normalized[:salary_max],
              salary_currency: normalized[:salary_currency],
              salary_period: normalized[:salary_period],
              location_city: normalized[:location_city],
              location_state: normalized[:location_state],
              location_country: normalized[:location_country],
              location_continent: normalized[:location_continent],
              location_scope: normalized[:location_scope]
            )
            existing = existing_job_row(db, source_name, source_key, source_url)

            if existing && unchanged_job?(existing, incoming)
              transaction_skipped_count += 1
              next
            end

            if existing && existing["source_url"].to_s == source_url.to_s && (existing["source"].to_s != source_name.to_s || existing["source_key"].to_s != source_key.to_s)
              transaction_updated_count += 1
              update_by_url_statement.execute(
                job.fetch(:title),
                job[:company],
                company_id,
                job[:location],
                native_boolean(job[:remote]),
                job[:employment_type],
                job[:category],
                job[:salary],
                job[:published_at],
                tags_json,
                job[:description],
                raw_json,
                normalized[:salary_min],
                normalized[:salary_max],
                normalized[:salary_currency],
                normalized[:salary_period],
                normalized[:location_city],
                normalized[:location_state],
                normalized[:location_country],
                normalized[:location_continent],
                normalized[:location_scope],
                now,
                source_url
              )
            else
              if existing
                transaction_updated_count += 1
              else
                transaction_inserted_count += 1
              end

              statement.execute(
                source_name,
                source_key,
                job.fetch(:title),
                job[:company],
                company_id,
                job[:location],
                native_boolean(job[:remote]),
                job[:employment_type],
                job[:category],
                job[:salary],
                source_url,
                job[:published_at],
                tags_json,
                job[:description],
                raw_json,
                normalized[:salary_min],
                normalized[:salary_max],
                normalized[:salary_currency],
                normalized[:salary_period],
                normalized[:location_city],
                normalized[:location_state],
                normalized[:location_country],
                normalized[:location_continent],
                normalized[:location_scope],
                now,
                now
              )
            end
          end
        end

        inserted_count = transaction_inserted_count
        updated_count = transaction_updated_count
        skipped_count = transaction_skipped_count
      end
      ImportStats.new(
        fetched_count: jobs.size,
        imported_count: jobs.size,
        inserted_count: inserted_count,
        updated_count: updated_count,
        skipped_count: skipped_count
      )
    ensure
      begin
        statement&.close
        update_by_url_statement&.close
      rescue StandardError
        nil
      end
      db&.close
    end

    def record_run(source_name, fetched_count, imported_count, status: "succeeded", error_message: nil)
      now = Time.now.utc.iso8601
      execute(<<~SQL)
        INSERT INTO source_runs (source, fetched_count, imported_count, inserted_count, updated_count, skipped_count, status, error_message, created_at)
        VALUES (#{quote(source_name)}, #{fetched_count.to_i}, #{imported_count.to_i}, 0, #{imported_count.to_i}, 0, #{quote(status)}, #{quote(error_message)}, #{quote(now)});
      SQL
    end

    def backfill_normalized_metadata
      execute("SELECT id, salary, location, remote FROM job_posts;", capture: true).each_line.each_slice(500) do |lines|
        sql = +"BEGIN;\n"
        lines.each do |line|
          id, salary, location, remote = line.chomp.split("|", 4)
          normalized = Normalizer.normalize(salary: salary, location: location, remote: remote.to_i == 1)
          sql << <<~SQL
            UPDATE job_posts SET
              salary_min = #{number(normalized[:salary_min])},
              salary_max = #{number(normalized[:salary_max])},
              salary_currency = #{quote(normalized[:salary_currency])},
              salary_period = #{quote(normalized[:salary_period])},
              location_city = #{quote(normalized[:location_city])},
              location_state = #{quote(normalized[:location_state])},
              location_country = #{quote(normalized[:location_country])},
              location_continent = #{quote(normalized[:location_continent])},
              location_scope = #{quote(normalized[:location_scope])}
            WHERE id = #{id.to_i};
          SQL
        end
        sql << "COMMIT;\n"
        execute(sql)
      end
    end

    def stats
      execute("SELECT source, COUNT(*) AS count FROM job_posts GROUP BY source ORDER BY count DESC;", capture: true)
    end

    def list(limit: 20)
      execute(<<~SQL, capture: true)
        SELECT source, title, company, location, COALESCE(published_at, ''), source_url
        FROM job_posts
        ORDER BY COALESCE(published_at, updated_at) DESC
        LIMIT #{Integer(limit)};
      SQL
    end

    def source_state(source_name)
      output = execute(<<~SQL, capture: true)
        SELECT COALESCE(next_cursor, ''), exhausted, COALESCE(last_error, '')
        FROM source_states
        WHERE source = #{quote(source_name)}
        LIMIT 1;
      SQL
      cursor, exhausted, last_error = output.lines.first.to_s.chomp.split("|", 3)
      {
        next_cursor: cursor.to_s.empty? ? nil : cursor,
        exhausted: exhausted.to_i == 1,
        last_error: last_error.to_s.empty? ? nil : last_error
      }
    end

    def save_source_state(source_name, next_cursor:, exhausted:, last_error: nil)
      now = Time.now.utc.iso8601
      execute(<<~SQL)
        INSERT INTO source_states (source, next_cursor, exhausted, last_error, updated_at)
        VALUES (#{quote(source_name)}, #{quote(next_cursor)}, #{boolean(exhausted)}, #{quote(last_error)}, #{quote(now)})
        ON CONFLICT(source) DO UPDATE SET
          next_cursor = excluded.next_cursor,
          exhausted = excluded.exhausted,
          last_error = excluded.last_error,
          updated_at = excluded.updated_at;
      SQL
    end

    private

    def create_schema
      execute(<<~SQL)
        PRAGMA journal_mode = WAL;

        CREATE TABLE IF NOT EXISTS job_posts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT NOT NULL,
          source_key TEXT NOT NULL,
          title TEXT NOT NULL,
          company TEXT,
          company_id TEXT,
          location TEXT,
          remote INTEGER,
          employment_type TEXT,
          category TEXT,
          salary TEXT,
          source_url TEXT NOT NULL,
          published_at TEXT,
          tags_json TEXT,
          description TEXT,
          raw_json TEXT,
          salary_min REAL,
          salary_max REAL,
          salary_currency TEXT,
          salary_period TEXT,
          location_city TEXT,
          location_state TEXT,
          location_country TEXT,
          location_continent TEXT,
          location_scope TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(source, source_key)
        );

        CREATE INDEX IF NOT EXISTS index_job_posts_source ON job_posts(source);
        CREATE INDEX IF NOT EXISTS index_job_posts_published_at ON job_posts(published_at);
        CREATE INDEX IF NOT EXISTS index_job_posts_company ON job_posts(company);
        CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_public
          ON job_posts(lower(trim(company)), published_at)
          WHERE company IS NOT NULL AND trim(company) != '';
        CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_active
          ON job_posts(lower(trim(company)), COALESCE(NULLIF(published_at, ''), '9999-12-31'))
          WHERE company IS NOT NULL AND trim(company) != '';
        CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_source
          ON job_posts(lower(trim(company)), lower(trim(source)))
          WHERE company IS NOT NULL AND trim(company) != ''
            AND source IS NOT NULL AND trim(source) != '';
        CREATE INDEX IF NOT EXISTS index_job_posts_normalized_company_country
          ON job_posts(lower(trim(company)), lower(trim(location_country)))
          WHERE company IS NOT NULL AND trim(company) != ''
            AND location_country IS NOT NULL AND trim(location_country) != '';
        CREATE INDEX IF NOT EXISTS index_job_posts_location ON job_posts(location);
        CREATE INDEX IF NOT EXISTS index_job_posts_remote ON job_posts(remote);
        CREATE INDEX IF NOT EXISTS index_job_posts_category ON job_posts(category);
        CREATE UNIQUE INDEX IF NOT EXISTS index_job_posts_source_url_unique ON job_posts(source_url);

        CREATE TABLE IF NOT EXISTS source_runs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT NOT NULL,
          fetched_count INTEGER NOT NULL DEFAULT 0,
          imported_count INTEGER NOT NULL DEFAULT 0,
          inserted_count INTEGER NOT NULL DEFAULT 0,
          updated_count INTEGER NOT NULL DEFAULT 0,
          skipped_count INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL,
          error_message TEXT,
          created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS source_states (
          source TEXT PRIMARY KEY,
          next_cursor TEXT,
          exhausted INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS job_quality_classifications (
          fingerprint TEXT PRIMARY KEY,
          source TEXT,
          source_key TEXT,
          source_url TEXT,
          title TEXT,
          score REAL NOT NULL,
          label TEXT,
          reason TEXT,
          provider TEXT,
          model TEXT,
          created_at TEXT NOT NULL
        );
      SQL
      add_column_if_missing("job_posts", "salary_min", "REAL")
      add_column_if_missing("job_posts", "company_id", "TEXT")
      add_column_if_missing("job_posts", "salary_max", "REAL")
      add_column_if_missing("job_posts", "salary_currency", "TEXT")
      add_column_if_missing("job_posts", "salary_period", "TEXT")
      add_column_if_missing("job_posts", "location_city", "TEXT")
      add_column_if_missing("job_posts", "location_state", "TEXT")
      add_column_if_missing("job_posts", "location_country", "TEXT")
      add_column_if_missing("job_posts", "location_continent", "TEXT")
      add_column_if_missing("job_posts", "location_scope", "TEXT")
      add_column_if_missing("source_runs", "inserted_count", "INTEGER NOT NULL DEFAULT 0")
      add_column_if_missing("source_runs", "updated_count", "INTEGER NOT NULL DEFAULT 0")
      add_column_if_missing("source_runs", "skipped_count", "INTEGER NOT NULL DEFAULT 0")
      execute(<<~SQL)
        CREATE INDEX IF NOT EXISTS index_job_posts_company_id_id
          ON job_posts(company_id, id DESC);
        CREATE INDEX IF NOT EXISTS index_job_posts_company_id_published_at
          ON job_posts(company_id, published_at);
        CREATE INDEX IF NOT EXISTS index_job_posts_salary_min ON job_posts(salary_min);
        CREATE INDEX IF NOT EXISTS index_job_posts_salary_max ON job_posts(salary_max);
        CREATE INDEX IF NOT EXISTS index_job_posts_location_city ON job_posts(location_city);
        CREATE INDEX IF NOT EXISTS index_job_posts_location_state ON job_posts(location_state);
        CREATE INDEX IF NOT EXISTS index_job_posts_location_country ON job_posts(location_country);
        CREATE INDEX IF NOT EXISTS index_job_posts_location_continent ON job_posts(location_continent);
        CREATE INDEX IF NOT EXISTS index_job_posts_location_scope ON job_posts(location_scope);
        CREATE INDEX IF NOT EXISTS index_job_quality_classifications_score ON job_quality_classifications(score);
        CREATE INDEX IF NOT EXISTS index_job_quality_classifications_source ON job_quality_classifications(source);
      SQL
    end

    def execute(sql, capture: false)
      out, err, status = Open3.capture3("sqlite3", @path, stdin_data: sql)
      raise "sqlite3 failed: #{err}" unless status.success?

      capture ? out : true
    end

    def add_column_if_missing(table, column, type)
      columns = execute("PRAGMA table_info(#{table});", capture: true)
      return if columns.lines.any? { |line| line.split("|")[1] == column }

      execute("ALTER TABLE #{table} ADD COLUMN #{column} #{type};")
    end

    def quote(value)
      return "NULL" if value.nil? || value == ""

      "'#{value.to_s.gsub("'", "''")}'"
    end

    def number(value)
      value.nil? ? "NULL" : value.to_f.to_s
    end

    def boolean(value)
      return "NULL" if value.nil?

      value ? "1" : "0"
    end

    def native_boolean(value)
      return nil if value.nil?

      value ? 1 : 0
    end

    def company_slug(company)
      slug = company.to_s.downcase
        .gsub("&", "and")
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-+|-+\z/, "")

      slug.empty? ? nil : slug
    end

    def existing_job_row(db, source_name, source_key, source_url)
      db.results_as_hash = true
      db.get_first_row(
        <<~SQL,
          SELECT
            source, source_key, title, company, company_id, location, remote, employment_type,
            category, salary, source_url, published_at, tags_json, description, raw_json,
            salary_min, salary_max, salary_currency, salary_period,
            location_city, location_state, location_country, location_continent, location_scope
          FROM job_posts
          WHERE (source = ? AND source_key = ?) OR source_url = ?
          ORDER BY CASE WHEN source = ? AND source_key = ? THEN 0 ELSE 1 END
          LIMIT 1
        SQL
        [source_name, source_key, source_url, source_name, source_key]
      )
    end

    def materialized_job_attributes(attrs)
      attrs
    end

    def unchanged_job?(existing, incoming)
      incoming.all? do |field, value|
        existing_value = existing[field.to_s]
        effective_value = if %i[description raw_json].include?(field) && blank?(value)
          existing_value
        else
          value
        end

        comparable_value(existing_value) == comparable_value(effective_value)
      end
    end

    def comparable_value(value)
      return "" if value.nil?
      return value.to_f if value.is_a?(Float)
      return value.to_i if value.is_a?(Integer)

      value.to_s
    end

    def blank?(value)
      value.nil? || value == ""
    end

    def with_sqlite_busy_retry
      attempts = Integer(ENV.fetch("SQLITE_BUSY_RETRY_ATTEMPTS", "5"))
      delay = Float(ENV.fetch("SQLITE_BUSY_RETRY_DELAY_SECONDS", "1.0"))
      attempt = 0

      begin
        yield
      rescue SQLite3::BusyException => e
        attempt += 1
        raise if attempt > attempts

        sleep(delay * attempt)
        retry
      end
    end
  end

    class HttpClient
    def get_json(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "application/json"
        http.request(request)
      end

      raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end

  class BrowserClient
    def dump_dom(url)
      command = [
        "chromium",
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--dump-dom",
        url
      ]
      out, err, status = Open3.capture3(*command)
      raise "chromium failed for #{url}: #{err.lines.first}" unless status.success?

      out
    end
  end

  module Gazetteer
    ROOT = File.expand_path("../..", __dir__)
    CITIES_JSON = File.join(ROOT, "data/json-cities.json")
    COUNTRIES_CSV = File.join(ROOT, "data/countries.csv")
    INDEX_JSON = File.join(ROOT, "data/location_index.json")

    module_function

    def resolve(text)
      value = text.to_s.strip
      return nil if value.empty?

      country = find_country(value)
      city_candidates(value).each do |candidate|
        entries = city_index[normalize_key(candidate)]
        next unless entries

        entry = if country
          entries.find { |item| item["country"].casecmp?(country["name"]) || item["country_code"].casecmp?(country["iso2"]) }
        else
          entries.first
        end
        return entry.merge("scope" => "city") if entry
      end

      return {
        "city" => nil,
        "state" => nil,
        "country" => country["name"],
        "country_code" => country["iso2"],
        "continent" => country["continent"],
        "scope" => "country"
      } if country

      nil
    end

    def find_country(text)
      key = normalize_key(text)
      exact = country_aliases[key]
      return exact if exact

      tokens = key.split
      country_aliases
        .sort_by { |alias_key, _country| -alias_key.length }
        .find do |alias_key, _country|
          if alias_key.length <= 3
            tokens.include?(alias_key)
          else
            key.match?(/\b#{Regexp.escape(alias_key)}\b/)
          end
        end&.last
    end

    def city_candidates(text)
      cleaned = text
        .gsub(/\b(Greater|Metro|Metropolitan|Area|Region|Remote|Hybrid|On-site|Onsite)\b/i, " ")
        .gsub(/\s+/, " ")
        .strip
      parts = cleaned.split(%r{[,;/|]|\bor\b|\band\b}i).map(&:strip).reject(&:empty?)
      ([cleaned] + parts + parts.map { |part| part.sub(/\s+(Area|Region)\z/i, "") }).uniq
    end

    def city_index
      @city_index ||= location_index.fetch("cities")
    end

    def country_aliases
      @country_aliases ||= location_index.fetch("countries")
    end

    def location_index
      return @location_index if @location_index

      build_index unless File.exist?(INDEX_JSON)
      @location_index = JSON.parse(File.read(INDEX_JSON))
    rescue StandardError => e
      warn "location gazetteer unavailable: #{e.message}"
      @location_index = { "cities" => {}, "countries" => {} }
    end

    def build_index
      raise "missing #{CITIES_JSON}" unless File.exist?(CITIES_JSON)
      raise "missing #{COUNTRIES_CSV}" unless File.exist?(COUNTRIES_CSV)

      countries_by_code = {}
      countries = {}
      CSV.foreach(COUNTRIES_CSV, headers: true) do |row|
        country = {
          "name" => row["name"],
          "iso2" => row["iso2"],
          "continent" => continent_name(row["region"], row["subregion"])
        }
        countries_by_code[row["iso2"]] = country
        [row["name"], row["iso2"], row["iso3"], row["native"]].compact.each do |alias_name|
          countries[normalize_key(alias_name)] = country
        end
      end
      countries["usa"] = countries["united states"]
      countries["us"] = countries["united states"]
      countries["uk"] = countries["united kingdom"]

      cities = Hash.new { |hash, key| hash[key] = [] }
      JSON.parse(File.read(CITIES_JSON)).each do |city|
        country = countries_by_code[city["country_code"]] || {}
        entry = {
          "city" => city["name"],
          "state" => city["state_name"],
          "country" => city["country_name"],
          "country_code" => city["country_code"],
          "continent" => country["continent"],
          "population" => city["population"].to_i
        }
        translations = city["translations"].is_a?(Hash) ? city["translations"] : {}
        ([city["name"]] + translations.values).compact.uniq.each do |name|
          key = normalize_key(name)
          next if key.empty?

          cities[key] << entry
        end
      end
      cities.transform_values! { |entries| entries.uniq.sort_by { |entry| -entry["population"].to_i }.first(8) }

      File.write(INDEX_JSON, JSON.generate("cities" => cities, "countries" => countries))
    end

    def normalize_key(value)
      value.to_s.downcase.gsub(/[^[:alnum:]\s]/, " ").gsub(/\s+/, " ").strip
    end

    def continent_name(region, subregion)
      return "North America" if subregion.to_s.match?(/Northern America|Central America|Caribbean/i)
      return "South America" if subregion.to_s.match?(/South America/i)

      region
    end
  end

  module Normalizer
    COUNTRY_CONTINENT = {
      "United States" => "North America",
      "USA" => "North America",
      "US" => "North America",
      "Canada" => "North America",
      "Brazil" => "South America",
      "Colombia" => "South America",
      "Argentina" => "South America",
      "Portugal" => "Europe",
      "Spain" => "Europe",
      "Germany" => "Europe",
      "France" => "Europe",
      "United Kingdom" => "Europe",
      "UK" => "Europe",
      "Ireland" => "Europe",
      "Netherlands" => "Europe",
      "Switzerland" => "Europe",
      "Poland" => "Europe",
      "Czechia" => "Europe",
      "Czech Republic" => "Europe",
      "United Arab Emirates" => "Asia",
      "UAE" => "Asia",
      "India" => "Asia",
      "Philippines" => "Asia",
      "Japan" => "Asia",
      "Singapore" => "Asia",
      "Australia" => "Oceania",
      "New Zealand" => "Oceania"
    }.freeze

    STATE_ABBREVIATIONS = {
      "AL" => ["Alabama", "United States", "North America"],
      "AK" => ["Alaska", "United States", "North America"],
      "AZ" => ["Arizona", "United States", "North America"],
      "AR" => ["Arkansas", "United States", "North America"],
      "CA" => ["California", "United States", "North America"],
      "CO" => ["Colorado", "United States", "North America"],
      "CT" => ["Connecticut", "United States", "North America"],
      "DC" => ["District of Columbia", "United States", "North America"],
      "FL" => ["Florida", "United States", "North America"],
      "GA" => ["Georgia", "United States", "North America"],
      "IL" => ["Illinois", "United States", "North America"],
      "MA" => ["Massachusetts", "United States", "North America"],
      "NJ" => ["New Jersey", "United States", "North America"],
      "NY" => ["New York", "United States", "North America"],
      "OR" => ["Oregon", "United States", "North America"],
      "TX" => ["Texas", "United States", "North America"],
      "WA" => ["Washington", "United States", "North America"]
    }.freeze

    CITY_COUNTRY = {
      "Berlin" => ["Berlin", nil, "Germany", "Europe"],
      "Munich" => ["Munich", "Bavaria", "Germany", "Europe"],
      "Düsseldorf" => ["Dusseldorf", "North Rhine-Westphalia", "Germany", "Europe"],
      "Augsburg" => ["Augsburg", "Bavaria", "Germany", "Europe"],
      "Landshut" => ["Landshut", "Bavaria", "Germany", "Europe"],
      "Chemnitz" => ["Chemnitz", "Saxony", "Germany", "Europe"],
      "London" => ["London", nil, "United Kingdom", "Europe"],
      "Paris" => ["Paris", nil, "France", "Europe"],
      "Lisbon" => ["Lisbon", nil, "Portugal", "Europe"],
      "New York" => ["New York", "NY", "United States", "North America"],
      "San Francisco" => ["San Francisco", "CA", "United States", "North America"],
      "Toronto" => ["Toronto", "ON", "Canada", "North America"]
    }.freeze

    CONTINENTS = %w[Africa Americas Asia Europe LATAM North\ America Oceania South\ America].freeze

    module_function

    def normalize(job)
      salary = normalize_salary(job[:salary])
      location = normalize_location(job[:location], remote: job[:remote])
      salary.merge(location)
    end

    def normalize_salary(value)
      text = value.to_s.strip
      return salary_result if text.empty? || text == "-"

      currency = detect_currency(text)
      period = detect_period(text)
      numbers = text.scan(/\d+(?:[.,]\d+)?\s*[kKmM]?/).map { |number| salary_number(number) }.compact
      return salary_result(currency: currency, period: period) if numbers.empty?

      salary_result(
        min: numbers.min,
        max: numbers.max,
        currency: currency,
        period: period
      )
    end

    def salary_number(value)
      raw = value.to_s.strip
      multiplier = raw.match?(/[kK]/) ? 1_000 : raw.match?(/[mM]/) ? 1_000_000 : 1
      numeric = raw.gsub(/[^\d.,]/, "")
      numeric = numeric.tr(",", ".") if numeric.count(",") == 1 && numeric.count(".").zero?
      numeric = numeric.gsub(",", "")
      numeric.to_f * multiplier
    end

    def detect_currency(text)
      return "USD" if text.include?("$") || text.match?(/\bUSD\b/i)
      return "EUR" if text.include?("€") || text.match?(/\bEUR\b/i)
      return "GBP" if text.include?("£") || text.match?(/\bGBP\b/i)

      nil
    end

    def detect_period(text)
      return "hour" if text.match?(/hour|hr|\/h/i)
      return "month" if text.match?(/month|monthly/i)
      return "year" if text.match?(/year|annual|annum|k\b/i)

      nil
    end

    def salary_result(min: nil, max: nil, currency: nil, period: nil)
      {
        salary_min: min,
        salary_max: max || min,
        salary_currency: currency,
        salary_period: period
      }
    end

    def normalize_location(value, remote: nil)
      text = value.to_s.strip
      return location_result(continent: "Worldwide", scope: "remote_worldwide") if text.empty? && remote
      return location_result(scope: nil) if text.empty?

      downcase = text.downcase
      return location_result(continent: "Worldwide", scope: "remote_worldwide") if downcase.match?(/\A(remoto|remote|flexible\s*\/\s*remote)\z/)
      return location_result(continent: "Worldwide", scope: "worldwide") if downcase.match?(/world\s*wide|worldwide|anywhere|global/)
      return location_result(continent: "Europe", scope: "region") if text.match?(/\b(EMEA|European Union|EU)\b/i)
      return location_result(continent: "South America", scope: "region") if text.match?(/\b(Latin America|LATAM)\b/i)
      return location_result(continent: "North America", scope: "country") if text.match?(/\bU\.?S\.?|United States|USA\b/i)

      cleaned_text = clean_location_text(text)
      gazetteer = Gazetteer.resolve(cleaned_text)
      if gazetteer
        return location_result(
          city: gazetteer["city"],
          state: gazetteer["state"],
          country: gazetteer["country"],
          continent: gazetteer["continent"],
          scope: gazetteer["scope"]
        )
      end

      state_match = state_from_text(cleaned_text)
      if state_match
        state, country, continent = state_match
        city = cleaned_text.split(",").first&.strip
        city = nil if city == state || city.to_s.empty?
        return location_result(city: city, state: state, country: country, continent: continent, scope: city ? "city" : "state")
      end

      continent = continent_from_text(cleaned_text)
      return location_result(continent: continent, scope: "region") if continent

      country = country_from_text(cleaned_text)
      return location_result(country: canonical_country(country), continent: COUNTRY_CONTINENT[country], scope: "country") if country

      first = cleaned_text.split(",").map(&:strip).find { |part| !part.empty? }
      city_data = CITY_COUNTRY[first]
      if city_data
        city, state, mapped_country, mapped_continent = city_data
        return location_result(city: city, state: state, country: mapped_country, continent: mapped_continent, scope: "city")
      end

      if cleaned_text.include?(",")
        parts = cleaned_text.split(",").map(&:strip)
        possible_country = country_from_text(parts.last)
        if possible_country
          return location_result(city: parts.first, country: canonical_country(possible_country), continent: COUNTRY_CONTINENT[possible_country], scope: "city")
        end
      end

      location_result(city: first, scope: remote ? "remote_unknown" : "unknown")
    end

    def clean_location_text(text)
      text.to_s
        .gsub(/\bNYC\b/i, "New York")
        .gsub(/\bSan Francisco Bay Area\b/i, "San Francisco")
        .gsub(/\b(Office|Coworking|Co-working|HQ|Depot|AV Depot)\b/i, " ")
        .gsub(/\b(Greater|Metro|Metropolitan|Area|Region)\b/i, " ")
        .gsub(/\A\s*[-–—]\s*/, "")
        .gsub(/\s*[-–—]\s*\z/, "")
        .gsub(/\s+/, " ")
        .strip
    end

    def state_from_text(text)
      tokens = text.to_s.split(/[\s,()]+/).map { |token| token.gsub(/[^A-Za-z]/, "").upcase }.reject(&:empty?)
      abbreviation = tokens.reverse.find { |token| STATE_ABBREVIATIONS.key?(token) }
      return STATE_ABBREVIATIONS[abbreviation] if abbreviation

      STATE_ABBREVIATIONS.values.find { |state, _country, _continent| text.match?(/\b#{Regexp.escape(state)}\b/i) }
    end

    def continent_from_text(text)
      return "South America" if text.match?(/\bLATAM\b/i)
      return "North America" if text.match?(/\bAmericas\b/i)

      CONTINENTS.find { |continent| text.match?(/\b#{Regexp.escape(continent)}\b/i) }
    end

    def country_from_text(text)
      return nil if text.nil?

      COUNTRY_CONTINENT.keys.find { |country| text.match?(/\b#{Regexp.escape(country)}\b/i) }
    end

    def canonical_country(country)
      case country
      when "USA", "US" then "United States"
      when "UK" then "United Kingdom"
      else country
      end
    end

    def location_result(city: nil, state: nil, country: nil, continent: nil, scope: nil)
      {
        location_city: city,
        location_state: state,
        location_country: country,
        location_continent: continent,
        location_scope: scope
      }
    end
  end

  module Sources
    class Base
      def initialize(client: HttpClient.new)
        @client = client
      end

      def fetch_fresh
        fetch
      end

      def fetch_backfill(_state)
        { jobs: [], next_cursor: nil, exhausted: true, last_error: nil }
      end

      private

      attr_reader :client

      def source_key(*parts)
        parts.compact.map(&:to_s).find { |part| !part.empty? } || Digest::SHA256.hexdigest(parts.join(":"))
      end

      def parse_time(value)
        return nil if value.nil? || value.to_s.empty?

        return Time.at(epoch_seconds(value)).utc.iso8601 if value.is_a?(Numeric)
        return Time.at(epoch_seconds(value.to_i)).utc.iso8601 if value.to_s.match?(/\A\d{10,}\z/)

        Time.parse(value.to_s).utc.iso8601
      rescue ArgumentError
        nil
      end

      def epoch_seconds(value)
        number = value.to_i
        number > 99_999_999_999 ? number / 1000 : number
      end

      def text(value)
        value.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
      end

      def html_description(value)
        value.to_s.strip
      end

      def label_list(*values)
        values.flatten.flat_map do |value|
          value.to_s.split(/\s*,\s*/)
        end.map { |value| human_label(value) }.reject(&:empty?).uniq
      end

      def human_label(value)
        value.to_s
          .tr("-", " ")
          .gsub(/\s*&\s*/, " & ")
          .gsub(/\s+/, " ")
          .strip
      end
    end

    class Remotive < Base
      def name = "remotive"

      def fetch
        payload = client.get_json("https://remotive.com/api/remote-jobs")
        payload.fetch("jobs", []).map do |job|
          {
            source_key: job.fetch("id").to_s,
            title: job.fetch("title"),
            company: job["company_name"],
            location: job["candidate_required_location"],
            remote: true,
            employment_type: job["job_type"],
            category: job["category"],
            salary: job["salary"],
            source_url: job.fetch("url"),
            published_at: parse_time(job["publication_date"]),
            tags: job["tags"] || [],
            description: html_description(job["description"]),
            raw: job
          }
        end
      end
    end

    class Arbeitnow < Base
      def name = "arbeitnow"

      def fetch
        fetch_pages(start_page: 1, max_pages: 1)[:jobs]
      end

      def fetch_url(url)
        payload = job_posting_from_html(fetch_html(url))
        return [] unless payload

        [normalize_detail(payload, url)]
      end

      def fetch_backfill(state)
        return { jobs: [], next_cursor: state[:next_cursor], exhausted: true, last_error: nil } if state[:exhausted]

        start_page = Integer(state[:next_cursor] || 2)
        fetch_pages(start_page: start_page, max_pages: Integer(ENV.fetch("BACKFILL_PAGES_PER_RUN", "0")))
      end

      private

      def fetch_pages(start_page:, max_pages:)
        jobs = []
        page = start_page
        pages_fetched = 0
        last_error = nil

        loop do
          break if max_pages.positive? && pages_fetched >= max_pages

          begin
            payload = client.get_json("https://www.arbeitnow.com/api/job-board-api?page=#{page}")
            page_jobs = payload.fetch("data", [])
            return { jobs: normalize(jobs), next_cursor: page, exhausted: true, last_error: nil } if page_jobs.empty?

            jobs.concat(page_jobs)
            pages_fetched += 1
            return { jobs: normalize(jobs), next_cursor: page + 1, exhausted: true, last_error: nil } unless payload.dig("links", "next")

            page += 1
          rescue RuntimeError
            raise if jobs.empty? && start_page == 1

            last_error = "blocked_or_limited_at_page=#{page}"
            return { jobs: normalize(jobs), next_cursor: page, exhausted: true, last_error: last_error }
          end
        end

        { jobs: normalize(jobs), next_cursor: page, exhausted: false, last_error: last_error }
      end

      def normalize(jobs)
        jobs.map do |job|
          {
            source_key: source_key(job["slug"], job["url"], job["title"]),
            title: job.fetch("title"),
            company: job["company_name"],
            location: job["location"],
            remote: job["remote"],
            source_url: job.fetch("url"),
            published_at: parse_time(job["created_at"]),
            tags: job["tags"] || [],
            description: html_description(job["description"]),
            raw: job
          }
        end
      end

      def normalize_detail(job, url)
        location = job.dig("jobLocation", "address") || {}

        {
          source_key: source_key(arbeitnow_slug(url), job.dig("identifier", "value"), url, job["title"]),
          title: job.fetch("title"),
          company: job.dig("hiringOrganization", "name"),
          location: [location["addressLocality"], location["addressRegion"], location["addressCountry"]].compact.join(", "),
          remote: nil,
          employment_type: job["employmentType"],
          category: nil,
          salary: salary_text(job["baseSalary"]),
          source_url: url,
          published_at: parse_time(job["datePosted"]),
          tags: Array(job["skills"]).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:empty?),
          description: html_description(job["description"]),
          raw: job.merge("arbeitnow_url" => url)
        }
      end

      def job_posting_from_html(html)
        Nokogiri::HTML(html).css("script[type='application/ld+json']").each do |script|
          payload = JSON.parse(script.text)
          posting = find_job_posting(payload)
          return posting if posting
        rescue JSON::ParserError
          next
        end

        nil
      end

      def find_job_posting(value)
        case value
        when Hash
          return value if Array(value["@type"]).include?("JobPosting") || value["@type"] == "JobPosting"

          Array(value["@graph"]).filter_map { |entry| find_job_posting(entry) }.first
        when Array
          value.filter_map { |entry| find_job_posting(entry) }.first
        end
      end

      def salary_text(value)
        salary = value.is_a?(Hash) ? value : {}
        amount = salary["value"].is_a?(Hash) ? salary["value"] : {}
        currency = salary["currency"]
        min = amount["minValue"]
        max = amount["maxValue"]
        unit = amount["unitText"]

        [currency, [min, max].compact.join("-"), unit].reject { |part| part.to_s.empty? }.join(" ")
      end

      def html_description(value)
        value.to_s.strip
      end

      def arbeitnow_slug(url)
        URI(url).path.split("/").last
      rescue URI::InvalidURIError
        nil
      end

      def fetch_html(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "text/html"
          http.request(request)
        end

        return fetch_html(URI.join(url, response["location"]).to_s) if response.is_a?(Net::HTTPRedirection) && response["location"]

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end
    end

    class TheMuse < Base
      CATEGORIES = [
        nil,
        "Account Management",
        "Accounting and Finance",
        "Administration and Office",
        "Advertising and Marketing",
        "Business Operations",
        "Computer and IT",
        "Customer Service",
        "Data and Analytics",
        "Design and UX",
        "Editor",
        "Education",
        "Engineering",
        "Healthcare",
        "Human Resources and Recruitment",
        "Legal Services",
        "Marketing",
        "Product",
        "Project Management",
        "Sales",
        "Software Engineering"
      ].freeze

      def name = "themuse"

      def fetch
        CATEGORIES.flat_map do |category|
          fetch_pages(start_page: 1, max_pages: Integer(ENV.fetch("THEMUSE_PAGES_PER_CATEGORY", "100")), category: category)[:jobs]
        end.uniq { |job| job[:source_key] }
      end

      def fetch_backfill(state)
        { jobs: [], next_cursor: state[:next_cursor], exhausted: true, last_error: nil }
      end

      private

      def fetch_pages(start_page:, max_pages:, category:)
        jobs = []
        page = start_page
        page_count = nil
        pages_fetched = 0
        last_error = nil

        while page_count.nil? || page <= page_count
          break if max_pages.positive? && pages_fetched >= max_pages

          begin
            url = "https://www.themuse.com/api/public/jobs?page=#{page}"
            url += "&category=#{URI.encode_www_form_component(category)}" if category
            payload = client.get_json(url)
            page_count ||= payload["page_count"].to_i if payload["page_count"]
            page_jobs = payload.fetch("results", [])
            return { jobs: normalize(jobs), next_cursor: page, exhausted: true, last_error: nil } if page_jobs.empty?

            jobs.concat(page_jobs)
            pages_fetched += 1
            page += 1
          rescue RuntimeError
            raise if jobs.empty? && start_page == 1

            last_error = "blocked_or_limited_at_page=#{page}"
            return { jobs: normalize(jobs), next_cursor: page, exhausted: true, last_error: last_error }
          end
        end

        exhausted = page_count && page > page_count
        { jobs: normalize(jobs), next_cursor: page, exhausted: exhausted, last_error: last_error }
      end

      def normalize(jobs)
        jobs.map do |job|
          locations = Array(job["locations"]).map { |location| location["name"] }
          {
            source_key: job.fetch("id").to_s,
            title: job.fetch("name"),
            company: job.dig("company", "name"),
            location: locations.join(", "),
            remote: locations.any? { |location| location.match?(/remote/i) },
            employment_type: Array(job["levels"]).map { |level| level["name"] }.join(", "),
            category: Array(job["categories"]).map { |category| category["name"] }.join(", "),
            source_url: job.dig("refs", "landing_page"),
            published_at: parse_time(job["publication_date"]),
            tags: job["tags"] || [],
            description: themuse_description(job),
            raw: job
          }
        end
      end

      def themuse_description(job)
        job["contents"].to_s.strip
      end
    end

    class RemoteJobs < Base
      def name = "remotejobs"

      def fetch
        fetch_pages(offset: 0, max_pages: 1)[:jobs]
      end

      def fetch_backfill(state)
        return { jobs: [], next_cursor: state[:next_cursor], exhausted: true, last_error: nil } if state[:exhausted]

        offset = Integer(state[:next_cursor] || 50)
        fetch_pages(offset: offset, max_pages: Integer(ENV.fetch("BACKFILL_PAGES_PER_RUN", "0")))
      end

      private

      def fetch_pages(offset:, max_pages:)
        limit = 50
        jobs = []
        pages_fetched = 0

        loop do
          break if max_pages.positive? && pages_fetched >= max_pages

          payload = client.get_json("https://remotejobs.org/api/v1/jobs?limit=#{limit}&offset=#{offset}")
          page_jobs = payload.fetch("data", [])
          return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: nil } if page_jobs.empty?

          jobs.concat(page_jobs)
          pages_fetched += 1
          offset += limit
          return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: nil } unless payload.dig("pagination", "has_more")
        end

        { jobs: normalize(jobs), next_cursor: offset, exhausted: false, last_error: nil }
      end

      def normalize(jobs)
        jobs.map do |job|
          {
            source_key: job.fetch("id").to_s,
            title: job.fetch("title"),
            company: job.dig("company", "name"),
            location: job["location"],
            remote: true,
            employment_type: job["type"],
            category: job.dig("category", "name"),
            salary: job["salary_text"],
            source_url: job["url"] || job["apply_url"],
            published_at: parse_time(job["posted_at"]),
            tags: [job.dig("category", "slug"), job["original_language"]].compact,
            description: html_description(job["description"]),
            raw: job
          }
        end
      end
    end

    class Himalayas < Base
      def name = "himalayas"

      def fetch
        fetch_pages(offset: 0, max_pages: 1)[:jobs]
      end

      def fetch_backfill(state)
        return { jobs: [], next_cursor: state[:next_cursor], exhausted: true, last_error: nil } if state[:exhausted]

        offset = Integer(state[:next_cursor] || 20)
        fetch_pages(offset: offset, max_pages: Integer(ENV.fetch("BACKFILL_PAGES_PER_RUN", "0")))
      end

      private

      def fetch_pages(offset:, max_pages:)
        limit = 20
        jobs = []
        total_count = nil
        pages_fetched = 0
        last_error = nil

        loop do
          break if max_pages.positive? && pages_fetched >= max_pages

          begin
            payload = client.get_json("https://himalayas.app/jobs/api?limit=#{limit}&offset=#{offset}")
            total_count ||= payload["totalCount"].to_i if payload["totalCount"]
            page_jobs = payload.fetch("jobs", [])
            return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: nil } if page_jobs.empty?

            jobs.concat(page_jobs)
            pages_fetched += 1
            offset += limit
            return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: nil } if total_count && offset >= total_count
          rescue RuntimeError
            raise if jobs.empty? && offset.zero?

            last_error = "blocked_or_limited_at_offset=#{offset}"
            return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: last_error }
          end
        end

        { jobs: normalize(jobs), next_cursor: offset, exhausted: false, last_error: last_error }
      end

      def normalize(jobs)
        jobs.map do |job|
          salary = [job["currency"], job["minSalary"], job["maxSalary"]].compact.join(" ")
          locations = Array(job["locationRestrictions"]).map { |location| location["name"] }
          categories = label_list(job["categories"])
          {
            source_key: job.fetch("guid").to_s,
            title: job.fetch("title"),
            company: job["companyName"],
            location: locations.empty? ? "Worldwide" : locations.join(", "),
            remote: true,
            employment_type: job["employmentType"],
            category: categories.first,
            salary: salary.empty? ? nil : salary,
            source_url: job.fetch("applicationLink"),
            published_at: parse_time(job["pubDate"]),
            tags: label_list(categories, job["parentCategories"], job["seniority"]),
            description: html_description(job["description"]),
            raw: job
          }
        end
      end
    end

    class HimalayasSearch < Base
      QUERIES = %w[
        software engineer developer backend frontend full-stack react node python ruby rails
        java golang rust elixir data engineer data scientist machine learning ai product manager
        designer devops sre security mobile android ios qa sales customer success marketing
      ].freeze

      COUNTRIES = %w[
        remote united-states canada brazil mexico argentina colombia chile portugal spain
        united-kingdom germany france netherlands ireland india singapore australia
      ].freeze

      def name = "himalayas_search"

      def fetch
        queries.flat_map do |query|
          fetch_query(q: query, offset: 0, max_pages: Integer(ENV.fetch("HIMALAYAS_SEARCH_PAGES_PER_QUERY", "1")))[:jobs]
        end.uniq { |job| job[:source_key] }
      end

      def fetch_backfill(state)
        return { jobs: [], next_cursor: state[:next_cursor], exhausted: true, last_error: nil } if state[:exhausted]

        query_index, country_index, offset = parse_cursor(state[:next_cursor])
        max_pages = Integer(ENV.fetch("BACKFILL_PAGES_PER_RUN", "0"))
        jobs = []
        pages = 0
        last_error = nil

        while query_index < queries.length
          query = queries[query_index]
          country = countries[country_index]
          result = fetch_query(q: query, country: country, offset: offset, max_pages: 1)
          jobs.concat(result[:jobs])
          pages += 1
          last_error = result[:last_error]

          if result[:exhausted]
            offset = 0
            country_index += 1
            if country_index >= countries.length
              country_index = 0
              query_index += 1
            end
          else
            offset = result[:next_cursor].to_i
          end

          break if max_pages.positive? && pages >= max_pages
        end

        exhausted = query_index >= queries.length
        next_cursor = exhausted ? nil : [query_index, country_index, offset].join(",")
        { jobs: jobs.uniq { |job| job[:source_key] }, next_cursor: next_cursor, exhausted: exhausted, last_error: last_error }
      end

      def fetch_query(q:, country: nil, offset: 0, max_pages: 1)
        limit = 20
        jobs = []
        total_count = nil
        pages_fetched = 0
        last_error = nil

        loop do
          break if max_pages.positive? && pages_fetched >= max_pages

          begin
            params = { "q" => q, "limit" => limit, "offset" => offset }
            params["country"] = country if country && country != "remote"
            params["remote"] = "true" if country == "remote"
            payload = client.get_json("https://himalayas.app/jobs/api/search?#{URI.encode_www_form(params)}")
            total_count ||= payload["totalCount"].to_i if payload["totalCount"]
            page_jobs = payload.fetch("jobs", [])
            return { jobs: normalize(page_jobs), next_cursor: offset, exhausted: true, last_error: nil } if page_jobs.empty?

            jobs.concat(page_jobs)
            pages_fetched += 1
            offset += limit
            return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: nil } if total_count && offset >= total_count
          rescue RuntimeError
            raise if jobs.empty? && offset.zero?

            last_error = "blocked_or_limited_at_offset=#{offset}"
            return { jobs: normalize(jobs), next_cursor: offset, exhausted: true, last_error: last_error }
          end
        end

        { jobs: normalize(jobs), next_cursor: offset, exhausted: false, last_error: last_error }
      end

      private

      def queries
        ENV.fetch("HIMALAYAS_SEARCH_QUERIES", QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def countries
        ENV.fetch("HIMALAYAS_SEARCH_COUNTRIES", COUNTRIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def parse_cursor(cursor)
        parts = cursor.to_s.split(/[|,]/).map(&:to_i)
        [parts[0] || 0, parts[1] || 0, parts[2] || 0]
      end

      def normalize(jobs)
        jobs.map do |job|
          salary = [job["currency"], job["minSalary"], job["maxSalary"]].compact.join(" ")
          locations = Array(job["locationRestrictions"]).map { |location| location.is_a?(Hash) ? location["name"] : location.to_s }
          categories = label_list(job["categories"])
          {
            source_key: job.fetch("guid").to_s,
            title: job.fetch("title"),
            company: job["companyName"],
            location: locations.empty? ? "Worldwide" : locations.join(", "),
            remote: job.to_s.match?(/remote/i) || locations.any? { |location| location.match?(/remote/i) } ? true : nil,
            employment_type: job["employmentType"],
            category: categories.first,
            salary: salary.empty? ? nil : salary,
            source_url: job.fetch("applicationLink"),
            published_at: parse_time(job["pubDate"]),
            tags: label_list(categories, job["parentCategories"], job["seniority"]),
            description: html_description(job["description"] || job["excerpt"]),
            raw: job
          }
        end
      end
    end

    class GetOnBoard < Base
      QUERIES = [
        "software engineer",
        "developer",
        "backend",
        "frontend",
        "full stack",
        "ruby",
        "python",
        "javascript",
        "typescript",
        "react",
        "node",
        "java",
        "golang",
        "data",
        "devops",
        "product manager",
        "designer",
        "qa"
      ].freeze

      def name = "getonbrd"

      def fetch
        queries.flat_map do |query|
          fetch_query(query: query, page: 1, max_pages: Integer(ENV.fetch("GETONBRD_PAGES_PER_QUERY", "1")))
        end.uniq { |job| job[:source_key] }
      end

      def fetch_query(query:, page: 1, max_pages: 1)
        jobs = []
        pages_fetched = 0

        loop do
          break if max_pages.positive? && pages_fetched >= max_pages

          payload = client.get_json("https://www.getonbrd.com/api/v0/search/jobs?#{URI.encode_www_form("query" => query, "page" => page)}")
          page_jobs = Array(payload["data"])
          break if page_jobs.empty?

          jobs.concat(page_jobs)
          pages_fetched += 1
          total_pages = payload.dig("meta", "total_pages").to_i
          break if total_pages.positive? && page >= total_pages

          page += 1
        end

        normalize(jobs)
      rescue StandardError => e
        warn "getonbrd query failed query=#{query.inspect} page=#{page}: #{e.class}: #{e.message}"
        []
      end

      private

      def queries
        ENV.fetch("GETONBRD_QUERIES", QUERIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def normalize(jobs)
        jobs.map do |job|
          attributes = job["attributes"] || {}
          salary = salary_text(attributes["min_salary"], attributes["max_salary"])
          url = job.dig("links", "public_url") || "https://www.getonbrd.com/jobs/#{job.fetch("id")}"

          {
            source_key: job.fetch("id").to_s,
            title: attributes.fetch("title"),
            company: company_name(job, attributes),
            location: location_text(attributes),
            remote: attributes["remote"],
            employment_type: nil,
            category: attributes["category_name"],
            salary: salary,
            source_url: url,
            published_at: parse_time(attributes["published_at"]),
            tags: tags(attributes),
            description: description_html(attributes),
            raw: job
          }
        end
      end

      def company_name(job, attributes)
        value = attributes["company_name"] || attributes.dig("company", "name")
        return value unless value.to_s.empty?

        slug_company(job["id"], attributes["title"])
      end

      def slug_company(id, title)
        tokens = id.to_s.split("-")
        tokens.pop if tokens.last.to_s.match?(/\A[a-z0-9]{4,8}\z/)
        title_tokens = title.to_s.downcase.gsub(/[^[:alnum:]\s]/, " ").split
        title_tokens.each do |token|
          break unless tokens.first == token

          tokens.shift
        end
        tokens.pop while tokens.last.to_s.match?(/\A(remote|remoto|hybrid|hibrido|onsite|presencial|latam|chile|mexico|colombia|peru|argentina|brazil|brasil)\z/i)
        name = tokens.join(" ")
        name.empty? ? nil : name.split.map(&:capitalize).join(" ")
      end

      def location_text(attributes)
        countries = Array(attributes["countries"]).map(&:to_s).reject(&:empty?)
        return countries.join(", ") unless countries.empty?
        return "Remote" if attributes["remote"]

        attributes["remote_modality"].to_s.empty? ? nil : attributes["remote_modality"]
      end

      def salary_text(min, max)
        values = [min, max].compact
        return nil if values.empty?

        "USD #{values.uniq.join(" - ")} / month"
      end

      def tags(attributes)
        [
          attributes["category_name"],
          attributes["remote_modality"],
          attributes["lang"],
          Array(attributes["perks"])
        ].flatten.compact.reject(&:empty?).uniq
      end

      def description_html(attributes)
        sections = [
          [attributes["description_headline"], attributes["description"]],
          ["Projects", attributes["projects"]],
          [attributes["functions_headline"], attributes["functions"]],
          [attributes["benefits_headline"], attributes["benefits"]],
          [attributes["desirable_headline"], attributes["desirable"]]
        ]

        sections.filter_map do |heading, body|
          body = body.to_s.strip
          next if body.empty?

          heading = heading.to_s.strip
          heading.empty? ? body : "<h3>#{escape_html(heading)}</h3>#{body}"
        end.join("\n")
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

    class RemoteOk < Base
      def name = "remoteok"

      def fetch
        payload = client.get_json("https://remoteok.com/api")
        payload.select { |item| item.is_a?(Hash) && item["id"] }.map do |job|
          {
            source_key: job.fetch("id").to_s,
            title: job.fetch("position"),
            company: job["company"],
            location: job["location"],
            remote: true,
            employment_type: job["job_type"],
            salary: job["salary"],
            source_url: job["url"] || "https://remoteok.com/remote-jobs/#{job["id"]}",
            published_at: parse_time(job["date"]),
            tags: job["tags"] || [],
            description: text(job["description"]),
            raw: job
          }
        end
      end
    end

    class Jobicy < Base
      INDUSTRIES = %w[
        dev design-multimedia marketing supporting sales product management
        finance-legal hr writing admin data-science
      ].freeze

      TAGS = %w[
        ruby rails elixir phoenix javascript typescript react node python django
        golang rust java kotlin android ios devops kubernetes security data ai ml
      ].freeze

      def name = "jobicy"

      def fetch
        queries = [nil] +
          INDUSTRIES.map { |industry| { "industry" => industry } } +
          TAGS.map { |tag| { "tag" => tag } }

        queries.flat_map { |query| fetch_query(query) }.uniq { |job| job[:source_key] }
      end

      private

      def fetch_query(query)
        params = { "count" => "100" }
        params.merge!(query) if query
        payload = client.get_json("https://jobicy.com/api/v2/remote-jobs?#{URI.encode_www_form(params)}")
        Array(payload["jobs"]).map do |job|
          salary = [job["salaryCurrency"], job["annualSalaryMin"], job["annualSalaryMax"]].compact.join(" ")
          {
            source_key: job.fetch("id").to_s,
            title: job.fetch("jobTitle"),
            company: job["companyName"],
            location: job["jobGeo"],
            remote: true,
            employment_type: Array(job["jobType"]).join(", "),
            category: Array(job["jobIndustry"]).join(", "),
            salary: salary.empty? ? nil : salary,
            source_url: job.fetch("url"),
            published_at: parse_time(job["pubDate"]),
            tags: Array(job["jobIndustry"]) + Array(job["jobLevel"]),
            description: text(job["jobDescription"] || job["jobExcerpt"]),
            raw: job
          }
        end
      rescue StandardError => e
        warn "jobicy query failed #{query.inspect}: #{e.message}"
        []
      end

      def xml_text(xml, tag)
        match = xml.match(%r{<#{tag}(?:\s[^>]*)?>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</#{tag}>}m)
        decode_xml(match ? match[1] : "").strip
      end

      def decode_xml(value)
        value.to_s
          .gsub("&amp;", "&")
          .gsub("&lt;", "<")
          .gsub("&gt;", ">")
          .gsub("&quot;", '"')
          .gsub("&apos;", "'")
      end
    end

    class Web3Career < Base
      API_TOKEN = "o8KS57qZNyYZfGAqqQnPuVDK5URZjgwH".freeze

      TAGS = %w[
        ai backend blockchain business-development community content crypto customer-success
        data defi design devops engineering finance frontend full-stack gaming go growth
        javascript legal marketing mobile nft node operations product product-manager python
        react remote rust sales security solidity support typescript web3
      ].freeze

      COUNTRIES = %w[
        united-states united-kingdom canada germany france portugal spain netherlands singapore
        hong-kong india united-arab-emirates australia brazil argentina mexico switzerland
        poland ireland japan south-korea thailand indonesia vietnam nigeria south-africa remote
      ].freeze

      def name = "web3career"

      def fetch
        ([nil] + TAGS.map { |tag| { "tag" => tag } } + COUNTRIES.map { |country| { "country" => country } })
          .flat_map { |query| fetch_api_query(query) }
          .uniq { |job| job[:source_key] }
      end

      def fetch_api_query(query = nil)
        params = {
          "limit" => "100",
          "token" => ENV.fetch("WEB3_CAREER_API_TOKEN", API_TOKEN)
        }
        params.merge!(query) if query

        payload = get_json("https://web3.career/api/v1?#{URI.encode_www_form(params)}")
        jobs = payload.find { |item| item.is_a?(Array) && item.first.is_a?(Hash) } || []
        jobs.map { |job| normalize_api_job(job) }
      rescue StandardError => e
        warn "web3career api query failed #{query.inspect}: #{e.class}: #{e.message}"
        []
      end

      def fetch_html_page(page)
        html = get_html("https://web3.career/?page=#{page}")
        doc = Nokogiri::HTML(html)

        doc.css("tr[data-jobid]").filter_map do |row|
          normalize_html_row(row)
        end
      rescue StandardError => e
        warn "web3career html page failed page=#{page.inspect}: #{e.class}: #{e.message}"
        []
      end

      def fetch_detail_description(url)
        html = get_html(url)
        doc = Nokogiri::HTML(html)

        meta_description =
          doc.at_css("meta[property='og:description']")&.[]("content") ||
          doc.at_css("meta[name='description']")&.[]("content")

        description = CGI.unescapeHTML(meta_description.to_s).strip
        return format_plain_description(description) unless description.empty?

        nil
      rescue StandardError => e
        warn "web3career detail failed url=#{url.inspect}: #{e.class}: #{e.message}"
        nil
      end

      def format_plain_description(description)
        text = description.to_s
        2.times { text = CGI.unescapeHTML(text) }
        text = text.gsub(/\s+/, " ").strip
        return nil if text.empty?

        text = text
          .gsub(/([a-z0-9])\.([A-Z])/, "\\1. \\2")
          .gsub(/([a-z0-9\)])([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,5})(?=:|[A-Z][a-z]|\z)/) do
            previous = Regexp.last_match(1)
            heading = Regexp.last_match(2)
            WEB3_HEADINGS.include?(heading) ? "#{previous}\n#{heading}" : Regexp.last_match(0)
          end

        heading_pattern = WEB3_HEADINGS.map { |heading| Regexp.escape(heading) }.join("|")
        chunks = text.split(/(?=\b(?:#{heading_pattern})(?=[:?\s-]|[A-Z]|\z))/i).map(&:strip).reject(&:empty?)

        chunks.map do |chunk|
          if (match = chunk.match(/\A(#{heading_pattern})[:?\s-]*(.*)\z/i))
            heading = CGI.escapeHTML(match[1])
            body = format_section_body(match[1], match[2].to_s.strip)
            body.empty? ? "<h4>#{heading}</h4>" : "<h4>#{heading}</h4>#{body}"
          else
            "<p>#{CGI.escapeHTML(chunk)}</p>"
          end
        end.join("\n")
      end

      private

      WEB3_HEADINGS = [
        "About Us",
        "About the Team",
        "Responsibilities",
        "Requirements",
        "Qualifications",
        "Benefits",
        "Join Tether and Shape the Future of Digital Finance",
        "At Tether",
        "Innovate with Tether",
        "Tether Finance",
        "Tether Power",
        "Tether Data",
        "Tether Education",
        "Tether Evolution",
        "About The Job",
        "About the job",
        "About The Role",
        "About the Role",
        "Why Join Us",
        "What You'll Do",
        "What You’ll Do",
        "Who You Are",
        "Your skills",
        "Technologies we use",
        "About Working With Us",
        "How You'll Grow",
        "How You’ll Grow"
      ].sort_by { |heading| -heading.length }.freeze

      WEB3_BULLET_LABELS = [
        "Developer Tooling",
        "Developer Advocacy",
        "Building dApps",
        "Documentation & Learning Resources",
        "Emerging Initiatives",
        "Prototyping mindset",
        "Developer communications",
        "AI adept",
        "Web3 curiosity",
        "Bonus points",
        "Nice to have",
        "Must have",
        "You have",
        "You are",
        "You will",
        "Responsibilities",
        "Requirements",
        "Benefits",
        "Work on",
        "Collaborate closely",
        "Integrate",
        "Manage",
        "Excellent programming skills",
        "Strong experience",
        "Good understanding",
        "Experience with",
        "Demonstrated ability",
        "Has experience",
        "Managing",
        "Regularly assessing",
        "Leveraging",
        "Ensuring"
      ].sort_by { |label| -label.length }.freeze

      WEB3_BULLET_SECTIONS = [
        "What You'll Do",
        "What You’ll Do",
        "Your skills",
        "Skills",
        "Responsibilities",
        "Requirements",
        "Qualifications"
      ].map(&:downcase).freeze

      def format_section_body(heading, body)
        return "" if body.empty?

        bullet_section = WEB3_BULLET_SECTIONS.include?(heading.downcase)
        body = insert_sentence_breaks(body) if bullet_section
        items = colon_bullet_items(heading, body)
        items = sentence_bullet_items(heading, body) if items.empty?
        return paragraph_html(body) if items.empty?

        preamble = body[0...items.first.fetch(:begin)].to_s.strip
        preamble_html = preamble.empty? ? "" : "<p>#{CGI.escapeHTML(preamble)}</p>"
        list = items.map do |item|
          label = CGI.escapeHTML(item.fetch(:label))
          text = CGI.escapeHTML(item.fetch(:text))
          label.empty? ? "<li>#{text}</li>" : "<li><strong>#{label}:</strong> #{text}</li>"
        end.join
        "#{preamble_html}<ul>#{list}</ul>"
      end

      def insert_sentence_breaks(body)
        WEB3_BULLET_LABELS.reduce(body.to_s) do |text, label|
          text.gsub(/([a-z0-9\)])\s+(#{Regexp.escape(label)}\b)/, "\\1\n\\2")
        end
      end

      def paragraph_html(body)
        body.to_s.split(/\n{1,}/).map(&:strip).reject(&:empty?).map do |paragraph|
          "<p>#{CGI.escapeHTML(paragraph)}</p>"
        end.join
      end

      def colon_bullet_items(heading, body)
        labels = WEB3_BULLET_LABELS.map { |label| Regexp.escape(label) }.join("|")
        matches = body.to_enum(:scan, /\b(#{labels})\s*:\s*/i).map do
          match = Regexp.last_match
          { label: match[1], begin: match.begin(0), end: match.end(0) }
        end
        return [] if matches.empty?

        bullet_section = WEB3_BULLET_SECTIONS.include?(heading.downcase)
        return [] if matches.length == 1 && !bullet_section

        matches.each_with_index.filter_map do |match, index|
          next_match = matches[index + 1]
          text = body[match[:end]...(next_match ? next_match[:begin] : body.length)].to_s.strip
          next if text.empty?

          { label: match[:label], text: text, begin: match[:begin] }
        end
      end

      def sentence_bullet_items(heading, body)
        return [] unless WEB3_BULLET_SECTIONS.include?(heading.downcase)

        lines = body.to_s.split(/\n+/).map(&:strip).reject(&:empty?)
        return [] if lines.length < 2

        preamble = []
        bullets = []

        lines.each do |line|
          if line.match?(/\A(?:#{WEB3_BULLET_LABELS.map { |label| Regexp.escape(label) }.join("|")})\b/i)
            bullets << line
          elsif bullets.empty?
            preamble << line
          else
            bullets << line
          end
        end

        return [] if bullets.empty?

        offset = preamble.join("\n").length
        bullets.map.with_index do |line, index|
          if (match = line.match(/\A(#{WEB3_BULLET_LABELS.map { |label| Regexp.escape(label) }.join("|")})[:\s-]*(.*)\z/i))
            { label: match[1], text: match[2].to_s.strip, begin: index.zero? ? offset : offset + 1 }
          else
            { label: "", text: line, begin: index.zero? ? offset : offset + 1 }
          end
        end
      end

      def normalize_api_job(job)
        salary = salary_text(
          job["salary_min_value"],
          job["salary_max_value"],
          job["salary_currency"],
          job["salary_unit"]
        )

        {
          source_key: job.fetch("id").to_s,
          title: job.fetch("title"),
          company: job["company"],
          location: [job["city"], job["country"], job["location"]].compact.map(&:to_s).reject(&:empty?).uniq.join(", "),
          remote: job["is_remote"],
          employment_type: nil,
          category: "Web3",
          salary: salary,
          source_url: job["apply_url"] || "https://web3.career/jobs/#{job["id"]}",
          published_at: parse_time(job["date_epoch"] || job["date"]),
          tags: Array(job["tags"]),
          description: job["description"],
          raw: job
        }
      end

      def normalize_html_row(row)
        id = row["data-jobid"].to_s
        href = row.at_css("a[href*='/#{id}']")&.[]("href") || row["onclick"].to_s[/['"]([^'"]+\/#{Regexp.escape(id)})['"]/, 1]
        return nil if id.empty? || href.to_s.empty?

        url = URI.join("https://web3.career", href).to_s
        title = row.at_css("h2")&.text.to_s.strip
        company = row.at_css("h3")&.text.to_s.strip
        location = row.css("td.job-location-mobile a[href*='web3-jobs']").map { |link| link.text.strip }.reject(&:empty?).join(", ")
        salary = row.at_css(".text-salary")&.text.to_s.gsub(/\s+/, " ").strip
        tags = row.css(".my-badge a").map { |link| link.text.strip }.reject(&:empty?).uniq

        {
          source_key: id,
          title: title,
          company: company,
          location: location,
          remote: location.match?(/remote/i) || tags.any? { |tag| tag.match?(/remote/i) } ? true : nil,
          employment_type: nil,
          category: "Web3",
          salary: salary.empty? ? nil : salary,
          source_url: url,
          published_at: parse_time(row.at_css("time")&.[]("datetime")),
          tags: tags,
          description: nil,
          raw: { "id" => id, "url" => url, "tags" => tags }
        }
      end

      def salary_text(min, max, currency, unit)
        values = [min, max].compact
        return nil if values.empty?

        prefix = currency.to_s.empty? ? nil : currency
        range = values.uniq.join(" - ")
        [prefix, range, unit].compact.reject(&:empty?).join(" ")
      end

      def get_html(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
          request["Accept"] = "text/html,application/xhtml+xml"
          request["Accept-Language"] = "en-US,en;q=0.9"
          request["Referer"] = "https://web3.career/"
          http.request(request)
        end

        return get_html(URI.join(url, response["location"]).to_s) if response.is_a?(Net::HTTPRedirection) && response["location"]
        return get_plain_html(url) if response.code.to_i == 403

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def get_plain_html(url)
        response = Net::HTTP.get_response(URI(url))
        return get_plain_html(URI.join(url, response["location"]).to_s) if response.is_a?(Net::HTTPRedirection) && response["location"]

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def get_json(url)
        JSON.parse(get(url, accept: "application/json"))
      end

      def get(url, accept:)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
          request["Accept"] = accept
          request["Accept-Language"] = "en-US,en;q=0.9"
          request["Referer"] = "https://web3.career/"
          http.request(request)
        end

        return get(URI.join(url, response["location"]).to_s, accept: accept) if response.is_a?(Net::HTTPRedirection) && response["location"]

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end
    end

    class GoogleCareers < Base
      BASE_URL = "https://www.google.com/about/careers/applications/jobs/results/".freeze

      def name = "google_careers"

      def fetch
        pages = Integer(ENV.fetch("GOOGLE_CAREERS_PAGES", "220"))
        (1..pages).flat_map { |page| fetch_page(page) }.uniq { |job| job[:source_key] }
      end

      def fetch_page(page)
        url = "#{BASE_URL}?page=#{page}"
        html = get_html(url)
        doc = Nokogiri::HTML(html)

        doc.css("a[href*='jobs/results/']").filter_map do |link|
          normalize_card(link)
        end.uniq { |job| job[:source_key] }
      rescue StandardError => e
        warn "google careers page failed page=#{page.inspect}: #{e.class}: #{e.message}"
        []
      end

      private

      def normalize_card(link)
        href = link["href"].to_s
        id = href[%r{jobs/results/(\d+)}, 1]
        return nil unless id

        card = link.ancestors.find { |node| node["class"].to_s.split.include?("sMn82b") } ||
          link.ancestors.find { |node| node.css("h3").any? && node.css("a[href*='jobs/results/']").size == 1 }
        return nil unless card

        title = card.at_css("h3")&.text.to_s.gsub(/\s+/, " ").strip
        return nil if title.empty?

        canonical = google_url(href)
        locations = card.css("span.r0wTof").map { |span| span.text.gsub(/\A\s*;\s*/, "").gsub(/\s+/, " ").strip }.reject(&:empty?).uniq
        location = locations.join("; ")
        level = card.at_css("h2")&.text.to_s.gsub(/\s+/, " ").strip
        description = description_html(card)

        {
          source_key: id,
          title: title,
          company: "Google",
          location: location.empty? ? nil : location,
          remote: card.text.match?(/remote eligible/i) ? true : nil,
          employment_type: nil,
          category: nil,
          salary: nil,
          source_url: canonical,
          published_at: nil,
          tags: [level].reject(&:empty?),
          description: description,
          raw: { "google_job_id" => id, "page" => href[/[?&]page=(\d+)/, 1] }
        }
      end

      def description_html(card)
        sections = card.css(".Xsxa1e")
        html = sections.map(&:inner_html).join("\n").strip
        return html unless html.empty?

        items = card.css("li").map { |li| "<li>#{escape_html(li.text.gsub(/\s+/, " ").strip)}</li>" }.join
        items.empty? ? nil : "<h4>Minimum qualifications</h4><ul>#{items}</ul>"
      end

      def get_html(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/125 Safari/537.36"
          request["Accept"] = "text/html,application/xhtml+xml"
          request["Accept-Language"] = "en-US,en;q=0.9"
          http.request(request)
        end

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body.to_s
      end

      def escape_html(value)
        CGI.escapeHTML(value.to_s)
      end

      def google_url(href)
        href = href.to_s.sub(/\?.*\z/, "")
        if href.start_with?("http")
          href
        else
          URI.join("https://www.google.com/about/careers/applications/", href).to_s
        end
      end
    end

    class BuiltIn < Base
      BASE_URL = "https://builtin.com/jobs".freeze

      def name = "builtin"

      def fetch
        pages = Integer(ENV.fetch("BUILTIN_PAGES", "20"))
        (1..pages).flat_map { |page| fetch_page(page) }.uniq { |job| job[:source_key] }
      end

      def fetch_page(page)
        url = page.to_i <= 1 ? BASE_URL : "#{BASE_URL}?page=#{page}"
        html = get_html(url)
        doc = Nokogiri::HTML(html)

        doc.css("a[href*='/job/']").filter_map do |link|
          normalize_card(link, url)
        end.uniq { |job| job[:source_key] }
      rescue StandardError => e
        warn "builtin page failed page=#{page.inspect}: #{e.class}: #{e.message}"
        []
      end

      private

      def normalize_card(link, base_url)
        href = link["href"].to_s
        return nil unless href.match?(%r{/job/})

        title = link.text.gsub(/\s+/, " ").strip
        return nil if title.empty? || title.length < 4

        canonical = URI.join(base_url, href).to_s.sub(/\?.*\z/, "")
        card = link.ancestors.find { |node| node["class"].to_s.include?("job-bounded-responsive") } ||
          link.ancestors.find { |node| node.css("a[href*='/job/']").size == 1 && node.text.include?(title) } ||
          link.parent
        company = company_name(card, link)
        body = card&.text.to_s.gsub(/\s+/, " ").strip
        detail = fetch_detail_job(canonical)
        return detail if detail

        {
          source_key: canonical[%r{/job/[^/]+/(\d+)}, 1] || Digest::SHA256.hexdigest(canonical),
          title: title,
          company: company,
          location: location_text(body, card),
          remote: body.match?(/remote/i) ? true : nil,
          employment_type: nil,
          category: nil,
          salary: salary_text(body),
          source_url: canonical,
          published_at: nil,
          tags: tags(body),
          description: body.empty? ? nil : "<p>#{CGI.escapeHTML(body)}</p>",
          raw: { "builtin_url" => canonical }
        }
      end

      def fetch_detail_job(url)
        return nil unless ENV.fetch("BUILTIN_FETCH_DETAIL", "true") == "true"

        html = get_html(url)
        job = json_ld_jobs(html).first
        return nil unless job

        canonical = job["url"].to_s.empty? ? url : URI.join(url, job["url"].to_s).to_s
        description = job["description"].to_s.strip

        {
          source_key: canonical[%r{/job/[^/]+/(\d+)}, 1] || Digest::SHA256.hexdigest(canonical),
          title: job["title"].to_s.strip,
          company: organization_name(job["hiringOrganization"]),
          location: location_name(job["jobLocation"]),
          remote: job.to_s.match?(/remote/i) ? true : nil,
          employment_type: Array(job["employmentType"]).reject(&:empty?).join(", "),
          category: nil,
          salary: salary_from_json_ld(job["baseSalary"]),
          source_url: canonical,
          published_at: parse_time(job["datePosted"]),
          tags: Array(job["employmentType"]).reject(&:empty?),
          description: description.empty? ? nil : description,
          raw: job.merge("builtin_url" => canonical)
        }
      rescue StandardError => e
        warn "builtin detail failed url=#{url}: #{e.class}: #{e.message}"
        nil
      end

      def json_ld_jobs(html)
        Nokogiri::HTML(html).css("script").flat_map do |script|
          next [] unless script["type"].to_s.casecmp("application/ld+json").zero?

          parse_json_ld(script.text)
        end
      end

      def parse_json_ld(script)
        find_job_postings(JSON.parse(CGI.unescapeHTML(script.to_s.strip)))
      rescue JSON::ParserError
        []
      end

      def find_job_postings(value)
        case value
        when Array
          value.flat_map { |entry| find_job_postings(entry) }
        when Hash
          type = value["@type"]
          matches = Array(type).map(&:to_s).any? { |item| item.casecmp("JobPosting").zero? } ? [value] : []
          graph = value["@graph"] ? find_job_postings(value["@graph"]) : []
          children = value.values.grep(Hash).flat_map { |child| find_job_postings(child) }
          matches + graph + children
        else
          []
        end
      end

      def organization_name(organization)
        return organization["name"].to_s.strip if organization.is_a?(Hash)

        organization.to_s.strip
      end

      def location_name(location)
        case location
        when Array
          location.map { |entry| location_name(entry) }.reject(&:empty?).join(", ")
        when Hash
          address = location["address"]
          return address.to_s.strip unless address.is_a?(Hash)

          [
            address["addressLocality"],
            address["addressRegion"],
            address["addressCountry"]
          ].compact.reject(&:empty?).join(", ")
        else
          location.to_s.strip
        end
      end

      def salary_from_json_ld(base_salary)
        return nil unless base_salary.is_a?(Hash)

        value = base_salary["value"]
        currency = base_salary["currency"].to_s
        period = value.is_a?(Hash) ? value["unitText"].to_s : nil
        min = value.is_a?(Hash) ? value["minValue"] : nil
        max = value.is_a?(Hash) ? value["maxValue"] : nil
        amount = value.is_a?(Hash) ? value["value"] : value

        range =
          if min && max
            "#{format_salary_amount(min)} - #{format_salary_amount(max)}"
          elsif amount
            format_salary_amount(amount)
          end

        [range, currency, period].compact.reject(&:empty?).join(" ")
      end

      def format_salary_amount(value)
        number = Float(value)
        number >= 10_000 ? number.round.to_s : number.to_s
      rescue ArgumentError, TypeError
        value.to_s
      end

      def company_name(card, job_link)
        company_link = card&.css("a[href^='/company/']")&.find { |link| !link.text.to_s.strip.empty? }
        company_text = company_link&.text.to_s.gsub(/\s+/, " ").strip
        return company_text unless company_text.empty?

        links = card&.css("a") || []
        value = links.find { |link| link != job_link && !link["href"].to_s.match?(%r{/job/}) }&.text.to_s
        value = value.gsub(/\s+/, " ").strip
        value.empty? ? nil : value
      end

      def location_text(body, card = nil)
        value = card&.css("span.font-barlow.text-gray-04")&.map { |span| span.text.gsub(/\s+/, " ").strip }&.find do |text|
          text.match?(/\b[A-Z][A-Za-z .'-]+,\s*[A-Z]{2},\s*USA\b/) ||
            text.match?(/\b(Remote|United States|India|Canada|United Kingdom|Brazil|Portugal|Germany|France|Netherlands|Singapore|Australia)\b/i)
        end
        return value if value && !value.match?(/\A(Remote|Hybrid|In-Office|In office|Onsite)\z/i)

        return "Remote" if body.match?(/\bRemote\b/i)

        body[/\b[A-Z][A-Za-z .'-]+,\s*[A-Z]{2},\s*USA\b/] ||
          body[/\b[A-Z][A-Za-z .'-]+,\s*[A-Z][A-Za-z .'-]+,\s*[A-Z][A-Za-z .'-]+\b/]
      end

      def salary_text(body)
        body[/\b\d{2,3}K\s*-\s*\d{2,3}K\s+(?:Annually|Hourly|Monthly)\b/i]
      end

      def tags(body)
        body.scan(/\b(?:Senior|Mid|Junior|Entry|Expert\/Leader) level\b/i).uniq
      end

      def get_html(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "text/html,application/xhtml+xml"
          http.request(request)
        end

        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body.to_s
      end
    end

    class BrowserJobPosting < Base
      DEFAULT_SEEDS = [
        "https://jobs.ashbyhq.com/openai",
        "https://jobs.ashbyhq.com/ashby",
        "https://jobs.ashbyhq.com/linear",
        "https://boards.greenhouse.io/stripe",
        "https://boards.greenhouse.io/airbnb",
        "https://boards.greenhouse.io/databricks"
      ].freeze

      def name = "browser"

      def initialize(client: Standalone::BrowserClient.new)
        @browser = client
        super(client: HttpClient.new)
      end

      def fetch
        detail_limit = Integer(ENV.fetch("BROWSER_DETAIL_LIMIT", "200"))
        seeds = ENV.fetch("BROWSER_SEED_URLS", DEFAULT_SEEDS.join(",")).split(",").map(&:strip).reject(&:empty?)
        detail_urls = seeds.flat_map { |url| discover_links(url) }.uniq.first(detail_limit)
        detail_urls.flat_map { |url| extract_jobs(url) }
      end

      private

      attr_reader :browser

      def discover_links(seed_url)
        html = browser.dump_dom(seed_url)
        links = html.scan(/href=["']([^"']+)["']/i).flatten
        absolute_links = links.filter_map do |href|
          next if href.start_with?("mailto:", "tel:", "#")

          URI.join(seed_url, href).to_s
        rescue URI::InvalidURIError
          nil
        end
        jobish = absolute_links.select do |url|
          url.match?(%r{/jobs?/|/job/|/careers?/|/postings?/|/boards?/|/openings?|/apply}i)
        end
        ([seed_url] + jobish).uniq
      rescue StandardError => e
        warn "browser discover failed #{seed_url}: #{e.message}"
        []
      end

      def extract_jobs(url)
        html = browser.dump_dom(url)
        jobs = json_ld_jobs(html).map { |job| normalize_json_ld(url, job) }
        jobs.empty? ? [fallback_job(url, html)].compact : jobs
      rescue StandardError => e
        warn "browser extract failed #{url}: #{e.message}"
        []
      end

      def json_ld_jobs(html)
        html.scan(%r{<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>}mi).flatten.flat_map do |script|
          parse_json_ld(script)
        end
      end

      def parse_json_ld(script)
        payload = JSON.parse(html_decode(script.strip))
        find_job_postings(payload)
      rescue JSON::ParserError
        []
      end

      def find_job_postings(value)
        case value
        when Array
          value.flat_map { |entry| find_job_postings(entry) }
        when Hash
          type = value["@type"]
          matches = Array(type).map(&:to_s).any? { |item| item.casecmp("JobPosting").zero? } ? [value] : []
          graph = value["@graph"] ? find_job_postings(value["@graph"]) : []
          children = value.values.grep(Hash).flat_map { |child| find_job_postings(child) }
          matches + graph + children
        else
          []
        end
      end

      def normalize_json_ld(url, job)
        organization = job["hiringOrganization"]
        location = job["jobLocation"]
        company = organization.is_a?(Hash) ? organization["name"] : organization.to_s
        location_text = case location
        when Array
          location.map { |entry| location_name(entry) }.reject(&:empty?).join(", ")
        when Hash
          location_name(location)
        else
          location.to_s
        end
        canonical = job["url"].to_s.empty? ? url : URI.join(url, job["url"].to_s).to_s
        {
          source_key: Digest::SHA256.hexdigest(canonical),
          title: job["title"].to_s,
          company: company,
          location: location_text,
          remote: job.to_s.match?(/remote/i) ? true : nil,
          employment_type: Array(job["employmentType"]).join(", "),
          salary: salary_text(job["baseSalary"]),
          source_url: canonical,
          published_at: parse_time(job["datePosted"]),
          tags: Array(job["employmentType"]),
          description: text(job["description"]),
          raw: job.merge("browser_url" => url)
        }
      end

      def fallback_job(url, html)
        title = meta(html, "og:title") || html[%r{<title[^>]*>(.*?)</title>}mi, 1]
        return nil unless title.to_s.match?(/job|engineer|developer|designer|manager|analyst|scientist|architect|product/i)

        {
          source_key: Digest::SHA256.hexdigest(url),
          title: html_decode(title).sub(/\s*\|.*\z/, "").strip,
          company: URI(url).host,
          location: nil,
          remote: html.match?(/remote/i),
          source_url: url,
          published_at: nil,
          tags: [],
          description: text(meta(html, "description").to_s),
          raw: { "browser_url" => url, "title" => title }
        }
      end

      def location_name(location)
        address = location["address"]
        return address.to_s unless address.is_a?(Hash)

        [
          address["addressLocality"],
          address["addressRegion"],
          address["addressCountry"]
        ].compact.join(", ")
      end

      def salary_text(salary)
        return nil unless salary.is_a?(Hash)

        value = salary["value"]
        return nil unless value.is_a?(Hash)

        [salary["currency"], value["minValue"], value["maxValue"], value["unitText"]].compact.join(" ")
      end

      def meta(html, name)
        html[%r{<meta[^>]+(?:property|name)=["']#{Regexp.escape(name)}["'][^>]+content=["']([^"']+)["']}i, 1] ||
          html[%r{<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']#{Regexp.escape(name)}["']}i, 1]
      end

      def html_decode(value)
        value.to_s
          .gsub("&amp;", "&")
          .gsub("&lt;", "<")
          .gsub("&gt;", ">")
          .gsub("&quot;", '"')
          .gsub("&#x27;", "'")
          .gsub("&apos;", "'")
      end
    end

    class Greenhouse < Base
      DEFAULT_BOARDS = %w[
        affirm airbnb anthropic applovin benchling calendly checkr coinbase databricks discord
        doordashusa duolingo figma grammarly instacart lyft notion plaid reddit rippling
        scaleai stripe toast twilio vercel zapier
      ].freeze

      def name = "greenhouse"

      def fetch
        boards.flat_map do |board|
          begin
            payload = client.get_json("https://boards-api.greenhouse.io/v1/boards/#{board}/jobs?content=true")
            payload.fetch("jobs", []).map { |job| normalize(board, job) }
          rescue StandardError
            []
          end
        end
      end

      private

      def boards
        ENV.fetch("GREENHOUSE_BOARDS", DEFAULT_BOARDS.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def normalize(board, job)
        offices = Array(job["offices"]).map { |office| office["name"] }.reject(&:empty?)
        departments = Array(job["departments"]).map { |department| department["name"] }.reject(&:empty?)
        {
          source_key: "#{board}:#{job.fetch("id")}",
          title: job.fetch("title"),
          company: board,
          location: offices.join(", "),
          remote: offices.any? { |office| office.match?(/remote/i) },
          category: departments.join(", "),
          source_url: job["absolute_url"],
          published_at: parse_time(job["updated_at"]),
          tags: departments,
          description: text(job["content"]),
          raw: job.merge("board" => board)
        }
      end
    end

    class Lever < Base
      DEFAULT_COMPANIES = %w[
        anduril benchling brex calendly datadog discord gitlab linear notion postman ramp
        reddit rippling scaleai vercel zapier
      ].freeze

      def name = "lever"

      def fetch
        companies.flat_map do |company|
          begin
            payload = client.get_json("https://api.lever.co/v0/postings/#{company}?mode=json")
            Array(payload).map { |job| normalize(company, job) }
          rescue StandardError
            []
          end
        end
      end

      private

      def companies
        ENV.fetch("LEVER_COMPANIES", DEFAULT_COMPANIES.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def normalize(company, job)
        categories = job["categories"] || {}
        location = categories["location"].to_s
        team = categories["team"].to_s
        {
          source_key: "#{company}:#{job.fetch("id")}",
          title: job.fetch("text"),
          company: company,
          location: location,
          remote: location.match?(/remote/i) ? true : nil,
          employment_type: categories["commitment"],
          category: team,
          source_url: job["hostedUrl"] || job["applyUrl"],
          published_at: parse_time(job["createdAt"]),
          tags: [team, categories["department"], categories["level"]].compact,
          description: lever_description(job),
          raw: job.merge("company_slug" => company)
        }
      end

      def lever_description(job)
        sections = []
        sections << job["description"].to_s.strip
        Array(job["lists"]).each do |list|
          title = list["text"].to_s.strip
          content = normalize_lever_content(list["content"].to_s.strip)
          next if title.empty? && content.empty?

          sections << [title.empty? ? nil : "<h3>#{escape_html(title)}</h3>", content].compact.join("\n")
        end
        sections << job["additional"].to_s.strip
        sections.reject(&:empty?).join("\n")
      end

      def normalize_lever_content(content)
        content = content.gsub(%r{</?div[^>]*>}i, "")
        return content unless content.match?(/<li[\s>]/i)

        content.gsub(%r{(?:\s*<li\b[^>]*>.*?</li>\s*)+}mi) do |items|
          items.match?(/<ul[\s>]/i) ? items : "<ul>#{items}</ul>"
        end
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

    class Ashby < Base
      DEFAULT_ORGS = %w[
        ashby cursor elevenlabs gleen linear openai perplexity ramp replit runway scale
        supabase vercel ycombinator
      ].freeze

      def name = "ashby"

      def fetch
        orgs.flat_map do |org|
          begin
            payload = client.get_json("https://api.ashbyhq.com/posting-api/job-board/#{org}")
            Array(payload["jobs"]).map { |job| normalize(org, job) }
          rescue StandardError
            []
          end
        end
      end

      private

      def orgs
        ENV.fetch("ASHBY_ORGS", DEFAULT_ORGS.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def normalize(org, job)
        location_value = job["location"]
        department_value = job["department"]
        location = location_value.is_a?(Hash) ? location_value["name"].to_s : location_value.to_s
        department = department_value.is_a?(Hash) ? department_value["name"] : department_value
        {
          source_key: "#{org}:#{job.fetch("id")}",
          title: job.fetch("title"),
          company: org,
          location: location,
          remote: location.match?(/remote/i) ? true : nil,
          employment_type: job["employmentType"],
          category: department,
          source_url: job["jobUrl"] || job["applyUrl"] || "https://jobs.ashbyhq.com/#{org}/#{job["id"]}",
          published_at: parse_time(job["publishedAt"]),
          tags: [department, job["employmentType"]].compact,
          description: text(job["descriptionHtml"] || job["descriptionPlain"]),
          raw: job.merge("org_slug" => org)
        }
      end
    end

    class LinkedinPublic < Base
      DEFAULT_KEYWORDS = [
        "developer",
        "software engineer",
        "backend engineer",
        "frontend engineer",
        "full stack engineer",
        "data engineer",
        "devops engineer",
        "site reliability engineer",
        "engineering manager",
        "head of engineering",
        "product manager",
        "data scientist",
        "machine learning engineer",
        "security engineer",
        "mobile developer"
      ].freeze

      DEFAULT_LOCATIONS = [
        "",
        "Lisbon",
        "Porto",
        "London",
        "Dublin",
        "Paris",
        "Berlin",
        "Munich",
        "Hamburg",
        "Amsterdam",
        "Madrid",
        "Barcelona",
        "Zurich",
        "Geneva",
        "Stockholm",
        "Copenhagen",
        "Oslo",
        "Helsinki",
        "Warsaw",
        "Krakow",
        "Prague",
        "Vienna",
        "Milan",
        "Rome",
        "New York",
        "San Francisco",
        "San Jose",
        "Seattle",
        "Austin",
        "Boston",
        "Chicago",
        "Los Angeles",
        "Denver",
        "Atlanta",
        "Miami",
        "Toronto",
        "Vancouver",
        "Montreal",
        "Sao Paulo",
        "Rio de Janeiro",
        "Buenos Aires",
        "Bogota",
        "Mexico City",
        "Singapore",
        "Tokyo",
        "Seoul",
        "Bengaluru",
        "Hyderabad",
        "Pune",
        "Mumbai",
        "Delhi",
        "Sydney",
        "Melbourne",
        "Brisbane",
        "Auckland",
        "Tel Aviv",
        "Dubai"
      ].freeze

      def name = "linkedin"

      def fetch
        []
      end

      def fetch_backfill(state)
        jobs = []
        final = nil
        fetch_backfill_batches(state).each do |batch|
          jobs.concat(batch[:jobs])
          final = batch
        end
        final ||= { next_cursor: state[:next_cursor], exhausted: true, last_error: nil }
        { jobs: jobs.uniq { |job| job[:source_key] }, next_cursor: final[:next_cursor], exhausted: final[:exhausted], last_error: final[:last_error] }
      end

      def fetch_backfill_batches(state)
        keywords = keyword_list
        locations = location_list
        pages_per_run = Integer(ENV.fetch("LINKEDIN_PAGES_PER_RUN", "200"))
        max_start = Integer(ENV.fetch("LINKEDIN_MAX_START", "999"))
        keyword_index, location_index, start = parse_cursor(state[:next_cursor])
        pages = 0
        Enumerator.new do |yielder|
          while keyword_index < keywords.length && pages < pages_per_run
            keyword = keywords[keyword_index]
            location = locations[location_index] || ""

            if start > max_start
              start = 0
              location_index += 1
              if location_index >= locations.length
                location_index = 0
                keyword_index += 1
              end
              next
            end

            begin
              page_jobs = fetch_page(keyword: keyword, location: location, start: start)
            rescue RateLimited => e
              yielder << {
                jobs: [],
                next_cursor: [keyword_index, location_index, start].join(","),
                exhausted: false,
                last_error: e.message
              }
              break
            end
            pages += 1
            start += 25

            if page_jobs.empty?
              start = max_start + 1
            end

            exhausted = keyword_index >= keywords.length
            next_cursor = exhausted ? nil : [keyword_index, location_index, start].join(",")
            yielder << { jobs: page_jobs, next_cursor: next_cursor, exhausted: exhausted, last_error: nil }
            sleep Float(ENV.fetch("LINKEDIN_PAGE_SLEEP_SECONDS", "0"))
          end

          if keyword_index >= keywords.length
            yielder << { jobs: [], next_cursor: nil, exhausted: true, last_error: nil }
          end
        end
      end

      private

      def keyword_list
        file = ENV["LINKEDIN_KEYWORDS_FILE"]
        return File.readlines(file, chomp: true).map(&:strip).reject(&:empty?) if file && File.exist?(file)

        ENV.fetch("LINKEDIN_KEYWORDS", DEFAULT_KEYWORDS.join(",")).split(",").map(&:strip).reject(&:empty?)
      end

      def location_list
        file = ENV["LINKEDIN_LOCATIONS_FILE"]
        return File.readlines(file, chomp: true).map(&:strip).reject(&:empty?) if file && File.exist?(file)

        raw = ENV["LINKEDIN_LOCATIONS"]
        return raw.split(",").map(&:strip) if raw && !raw.empty?

        DEFAULT_LOCATIONS
      end

      def parse_cursor(cursor)
        parts = cursor.to_s.split(/[|,]/).map(&:to_i)
        [parts[0] || 0, parts[1] || 0, parts[2] || 0]
      end

      def fetch_page(keyword:, location:, start:)
        params = { "keywords" => keyword, "position" => 1, "pageNum" => start / 25, "start" => start }
        params["location"] = location unless location.empty?
        url = "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?#{URI.encode_www_form(params)}"
        html = http_get(url)
        cards = html.scan(%r{<li>\s*(.*?)\s*</li>}m).flatten
        cards.filter_map { |card| parse_card(card) }
      rescue StandardError => e
        raise RateLimited, e.message if e.message.include?("HTTP 429")

        warn "linkedin page failed keyword=#{keyword.inspect} location=#{location.inspect} start=#{start}: #{e.message}"
        []
      end

      def fetch_detail_description(id)
        url = "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/#{id}"
        html = http_get(url, referer: "https://www.linkedin.com/jobs/view/#{id}/", browser: true)
        description = html[%r{<div class="show-more-less-html__markup[^"]*"[^>]*>(.*?)</div>}m, 1]
        description = html[%r{<section class="show-more-less-html"[^>]*>.*?<div[^>]*>(.*?)</div>}m, 1] if description.to_s.empty?
        cleaned = html_decode(description.to_s).strip
        cleaned.empty? ? nil : cleaned
      rescue StandardError => e
        raise RateLimited, e.message if e.message.include?("HTTP 429")

        warn "linkedin detail failed id=#{id.inspect}: #{e.message}"
        nil
      end

      def http_get(url, referer: nil, browser: false)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = browser ? "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36" : USER_AGENT
          request["Accept"] = "text/html,application/xhtml+xml"
          request["Referer"] = referer if referer
          http.request(request)
        end
        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.body.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      end

      def parse_card(card)
        id = card[/urn:li:jobPosting:(\d+)/, 1] || card[%r{/jobs/view/[^-]+-(\d+)}, 1]
        return nil unless id

        title = html_text(card[%r{base-search-card__title[^>]*>(.*?)</h3>}m, 1]) ||
          html_text(card[%r{<span class="sr-only">\s*(.*?)\s*</span>}m, 1])
        company = html_text(card[%r{base-search-card__subtitle[^>]*>.*?<a[^>]*>(.*?)</a>}m, 1]) ||
          html_text(card[%r{base-search-card__subtitle[^>]*>(.*?)</h4>}m, 1])
        location = html_text(card[%r{job-search-card__location[^>]*>(.*?)</span>}m, 1])
        return nil if title.to_s.empty?

        posted_at = card[%r{datetime="([^"]+)"}i, 1]
        {
          source_key: id,
          title: title,
          company: company,
          location: location,
          remote: location.to_s.match?(/remote/i) ? true : nil,
          source_url: "https://www.linkedin.com/jobs/view/#{id}",
          published_at: parse_time(posted_at),
          tags: [],
          description: nil,
          raw: { "linkedin_job_id" => id }
        }
      end

      def html_text(value)
        cleaned = text(html_decode(value.to_s))
        cleaned.empty? ? nil : cleaned
      end

      def html_decode(value)
        value.to_s
          .gsub("&amp;", "&")
          .gsub("&lt;", "<")
          .gsub("&gt;", ">")
          .gsub("&quot;", '"')
          .gsub("&#x27;", "'")
          .gsub("&#39;", "'")
          .gsub("&apos;", "'")
      end
    end
  end

  class Runner
    SOURCES = [
      Sources::Remotive,
      Sources::Arbeitnow,
      Sources::TheMuse,
      Sources::RemoteOk,
      Sources::RemoteJobs,
      Sources::Himalayas,
      Sources::HimalayasSearch,
      Sources::Jobicy,
      Sources::GetOnBoard,
      Sources::Web3Career,
      Sources::GoogleCareers,
      Sources::BuiltIn,
      Sources::Greenhouse,
      Sources::Lever,
      Sources::Ashby,
      Sources::BrowserJobPosting,
      Sources::LinkedinPublic
    ].freeze

    def initialize(db_path:)
      @db = Database.new(db_path)
    end

    def crawl(source_names: nil)
      selected_sources = if source_names && !source_names.empty?
        SOURCES.select { |source_class| source_names.include?(source_class.new.name) }
      else
        SOURCES
      end

      selected_sources.each do |source_class|
        source = source_class.new
        begin
          state = @db.source_state(source.name)
          fresh_jobs = source.fetch_fresh
          if source.respond_to?(:fetch_backfill_batches)
            fetched = fresh_jobs.size
            imported = @db.upsert_jobs(source.name, fresh_jobs)
            last_batch = nil

            source.fetch_backfill_batches(state).each do |batch|
              batch_jobs = batch.fetch(:jobs)
              fetched += batch_jobs.size
              imported += @db.upsert_jobs(source.name, batch_jobs)
              @db.save_source_state(
                source.name,
                next_cursor: batch[:next_cursor],
                exhausted: batch[:exhausted],
                last_error: batch[:last_error]
              )
              last_batch = batch
            end

            last_batch ||= { next_cursor: state[:next_cursor], exhausted: true, last_error: nil }
            @db.record_run(source.name, fetched, imported)
            cursor = last_batch[:next_cursor] ? ", next=#{last_batch[:next_cursor]}" : ""
            done = last_batch[:exhausted] ? ", backfill=done" : ", backfill=running"
            puts "#{source.name}: fetched #{fetched}, upserted #{imported}#{cursor}#{done}"
          else
            backfill = source.fetch_backfill(state)
            jobs = fresh_jobs + backfill.fetch(:jobs)
            imported = @db.upsert_jobs(source.name, jobs)
            @db.save_source_state(
              source.name,
              next_cursor: backfill[:next_cursor],
              exhausted: backfill[:exhausted],
              last_error: backfill[:last_error]
            )
            @db.record_run(source.name, jobs.size, imported)
            cursor = backfill[:next_cursor] ? ", next=#{backfill[:next_cursor]}" : ""
            done = backfill[:exhausted] ? ", backfill=done" : ", backfill=running"
            puts "#{source.name}: fetched #{jobs.size}, upserted #{imported}#{cursor}#{done}"
          end
        rescue StandardError => e
          @db.record_run(source.name, 0, 0, status: "failed", error_message: "#{e.class}: #{e.message}")
          warn "#{source.name}: #{e.class}: #{e.message}"
        end
      end
    end

    def stats
      puts @db.stats
    end

    def list(limit: 20)
      puts @db.list(limit: limit)
    end

    def normalize
      @db.backfill_normalized_metadata
      puts "normalized metadata backfilled"
    end

    def forever(source_names: nil, sleep_seconds: Integer(ENV.fetch("CRAWL_SLEEP_SECONDS", "300")))
      loop do
        crawl(source_names: source_names)
        sleep sleep_seconds
      end
    end
  end
end
