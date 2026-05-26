# Caio Crawler

Rails and Sidekiq ingestion system for collecting public tech job postings into a normalized SQLite database.

The crawler is built as the ingestion half of the Caio monorepo. It handles source fanout, source-specific fetches, deduplication, location/salary normalization, and write-side persistence into `job_posts`.

## Core Responsibilities

- Crawl public job APIs, ATS feeds, and public job search pages.
- Queue source fanout and page fetch work through Sidekiq.
- Deduplicate jobs by source/source key and canonical URL.
- Normalize metadata such as salary range, currency, city, state, country, and continent.
- Keep source cursors so repeated runs resume instead of wasting requests.

## Rails/Sidekiq Setup

```sh
bundle install
bin/rails db:migrate
bundle exec sidekiq -C config/sidekiq_sources.yml
```

Useful Sidekiq profiles:

```sh
bundle exec sidekiq -C config/sidekiq_fetch.yml
bundle exec sidekiq -C config/sidekiq_writer.yml
bundle exec sidekiq -C config/sidekiq_sources.yml
```

Enqueue work:

```sh
bin/rails runner "SourceFanoutSchedulerWorker.perform_async"
bin/rails runner "LinkedinSchedulerWorker.perform_async"
```

Inspect Sidekiq queues from Rails console:

```ruby
Sidekiq::Queue.all.map { |q| [q.name, q.size] }.to_h
Sidekiq::RetrySet.new.size
Sidekiq::Stats.new.processed
```

## Local Batch Runner

For quick local runs without keeping Sidekiq open:

```sh
ruby bin/local_crawl crawl
ruby bin/local_crawl forever
ruby bin/local_crawl stats
ruby bin/local_crawl list
```

`crawl` runs one cycle. `forever` keeps cycling and sleeps between cycles.

```sh
CRAWL_SLEEP_SECONDS=300 ruby bin/local_crawl forever
```

The standalone runner stores source cursors in `source_states`. Each cycle polls the freshest page/feed for every source, then resumes unfinished historical backfill from the stored cursor instead of restarting from page 1.

Useful targeted runs:

```sh
ruby bin/local_crawl crawl himalayas
BACKFILL_PAGES_PER_RUN=25 ruby bin/local_crawl crawl himalayas
CRAWL_SLEEP_SECONDS=60 ruby bin/local_crawl forever himalayas
```

The default database is `db/development.sqlite3`. Override it with:

```sh
JOB_CRAWLER_DB=/path/to/jobs.sqlite3 ruby bin/local_crawl crawl
```

## Rake Tasks

```sh
bin/rails crawler:crawl_all
TARGET_JOBS=1000000 bin/rails crawler:crawl_until_target
```

## Sources

Included adapters and workers cover sources such as:

- Remotive public API
- Arbeitnow public API
- The Muse public jobs API
- Remote OK API
- Himalayas
- Himalayas search API fanout across role/country filters
- Remote Jobs
- Get on Board public API for LATAM tech jobs
- LinkedIn public guest job search endpoints

Before scaling any source, review its current API terms, attribution requirements, robots.txt, and rate limits. The crawler should degrade gracefully under rate limiting and avoid retry storms.

## Database

The default database is:

```text
db/development.sqlite3
```

It is intentionally ignored by git. The portal reads this same database during local development.

## Operational Notes

- Use Redis-backed Sidekiq workers for long-running crawls.
- Keep generated databases, WAL files, logs, and large location indexes out of git.
- Prefer adding source-specific adapters over one-off scraping code.
- Store enough cursor state to resume safely after crashes or restarts.
