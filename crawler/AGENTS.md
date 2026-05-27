# Caio Crawler Agent Notes

This is the Rails/Sidekiq ingestion app for Caio. Also read the root
`AGENTS.md` before editing this app.

## What This App Owns

- Public job-source adapters.
- Source fanout and Sidekiq queueing.
- Job normalization, deduplication, quality filtering, and imports.
- Description repair/backfill workers.
- Source cursor state and import metrics.
- Writing job records into the SQLite database served by the Phoenix portal.

The crawler is production-critical because bad normalization immediately becomes
bad public UX.

## Source Adapter Rules

- Preserve structured job descriptions when the source provides HTML or rich
  text. Paragraphs, headings, bullets, and lists should be stored before the
  portal renders them.
- Do not flatten HTML into plain text unless the source truly has no structure.
- Store enough raw source data in `raw_json` to debug and repair records later.
- Use stable source keys and canonical URLs so re-crawls update existing jobs
  instead of duplicating them.
- Keep source-specific fixes close to the relevant adapter/worker.
- Be conservative with public endpoints: respect rate limits, avoid retry storms,
  and degrade gracefully when a source blocks or changes.

## Database And Imports

- Local default DB: `crawler/db/development.sqlite3`.
- Production DB: `/var/lib/caio/caio.sqlite3`.
- The portal reads the same database, so schema/index changes must be compatible
  with both Rails and Phoenix.
- Prefer migrations for schema/index changes. Do not hand-create production
  indexes unless the user explicitly asks for an emergency fix.
- Rails schema dumping should stay disabled because Phoenix owns SQLite FTS
  virtual tables that can break Rails schema dumps.
- Import metrics may include updates as well as inserts; be explicit when
  changing reporting semantics.

## Sidekiq Queues

The main profiles are:

```sh
bundle exec sidekiq -C config/sidekiq_sources.yml
bundle exec sidekiq -C config/sidekiq_fetch.yml
bundle exec sidekiq -C config/sidekiq_writer.yml
```

Useful enqueue commands:

```sh
bin/rails runner "SourceFanoutSchedulerWorker.perform_async"
bin/rails runner "LinkedinSchedulerWorker.perform_async"
```

Use queue-specific workers when possible instead of one large catch-all process.

## Local Commands

From `crawler/`:

```sh
bundle install
bin/rails db:migrate
ruby bin/local_crawl stats
ruby bin/local_crawl crawl himalayas
```

Target production DB manually only when intended:

```sh
RAILS_ENV=production JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3 bundle exec rails db:migrate
```

## Verification

- For Ruby syntax-only edits, run `ruby -c` on changed Ruby files.
- For adapter changes, test one real known source/job when network access is
  available.
- For repair workers, validate on a small limit first before suggesting large
  production batches.
- When changing import behavior, check whether `JobPostImportWorker` still
  preserves existing better data and updates only fields that should change.

## Operational Cautions

- Do not clear Redis queues or delete local databases unless explicitly asked.
- Do not assume development queued jobs exist in production; Redis queue state is
  environment-specific.
- If production counts are stuck, confirm workers use
  `JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3` and are not writing to
  `db/development.sqlite3`.
- Before blaming the portal, inspect recent `source_runs`, Sidekiq queue sizes,
  and the database file that is actually growing.
