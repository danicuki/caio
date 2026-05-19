# Scaling Plan

## First milestone: reliable ingestion

- Keep source adapters explicit and auditable.
- Store source attribution and original URL for every job.
- Persist raw payloads so parsing can be improved without re-fetching.
- Track every crawl run with counts and errors.
- Deduplicate by `(source, source_key)` first; add cross-source canonicalization later.

## Path to one million jobs

Reaching one million active or historical jobs requires more than a loop:

- Add many source adapters: ATS boards such as Greenhouse, Lever, Workable, Ashby, SmartRecruiters, and public government feeds.
- Discover company career pages through sitemaps and ATS board indexes.
- Respect robots.txt, API terms, and rate limits per domain.
- Use Redis-backed Sidekiq queues with source-specific concurrency.
- Move from SQLite to Postgres before high-volume writes.
- Add full-text search indexing separately from ingestion.

SQLite is acceptable for the first local batch and development, but it is not the right storage layer for a multi-worker million-row crawler.

