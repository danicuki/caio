# Caio Agent Context

This file gives Codex sessions the durable project context that is otherwise easy
to lose between chats. Read it before making changes in this repository.

## Product Direction

Caio is not intended to be only a jobs board. The public job index is the data
layer and lead-generation surface for a larger product: a supervised job-search
agent that helps candidates find relevant roles, tailor application material,
apply, and track outcomes.

The current repo should stay simple, fast, and production-practical. Prefer
small, reliable improvements over architecture that only pays off later.

## Repository Layout

- `crawler/`: Ruby/Rails + Sidekiq ingestion system. It fetches public job
  sources, normalizes records, deduplicates, and writes to SQLite.
- `portal/`: Phoenix/Elixir web app. It renders the public UI, search, job
  detail pages, company pages, unlock/login flows, apply tracking, SEO, and
  analytics.
- `deploy/`: Google Cloud VM deployment docs, scripts, Caddy/systemd examples,
  and operational notes.
- `marketing/`: launch copy and social media drafts.
- `design/`: prototype/reference assets. Treat as source material; do not commit
  large generated design exports unless explicitly asked.

There is also `portal/AGENTS.md` with Phoenix-specific framework rules. Read it
before editing the Phoenix app.

## Development Defaults

- Use `rg`/`rg --files` for searching.
- Keep changes scoped to the user request.
- Preserve existing uncommitted work. Do not revert or rewrite files you did not
  touch unless the user explicitly asks.
- Prefer migrations for database/index changes. Do not create production indexes
  manually unless the user explicitly asks for an emergency operation.
- Do not commit secrets. Use `.env` locally and `/etc/caio/caio.env` in
  production.
- Do not add new paid services, external design tools, or large dependencies
  without a clear reason.
- Keep git history flat. For feature branches, rebase on `main`; do not create
  merge commits unless explicitly requested.

## Local Commands

From the repository root:

```sh
bin/run_local_stack --restart
```

Useful focused commands:

```sh
cd portal
mix compile
mix test
mix format
mix assets.deploy
MIX_ENV=prod mix release --overwrite
```

```sh
cd crawler
bundle install
bin/rails db:migrate
bundle exec sidekiq -C config/sidekiq_sources.yml
bundle exec sidekiq -C config/sidekiq_fetch.yml
bundle exec sidekiq -C config/sidekiq_writer.yml
```

The local portal normally reads the crawler database at:

```text
crawler/db/development.sqlite3
```

Production uses:

```text
/var/lib/caio/caio.sqlite3
```

## Important Implementation Notes

- Job descriptions must preserve source HTML when the source provides real
  structure. Do not rely on Phoenix display heuristics to recreate paragraphs,
  bullets, or lists after a crawler has flattened them.
- Search/result counts should distinguish visible/active jobs from stale,
  invalid, or inactive rows when product copy implies freshness.
- Company pages should be fast. Prefer precomputed company records/stats and
  indexed lookups over aggregate scans on every request.
- Company logos should come from stored company data with graceful fallbacks,
  not from expensive request-time lookups.
- Apply clicks must record user/lead intent before redirecting to the external
  source.
- Guest unlock and job-apply capture should use the same simple modal/profile
  collection pattern when possible.
- Social login is GitHub-only unless the product decision changes.
- PostHog is used for product analytics. Do not hardcode keys.

## Production Deploy Notes

The production VM runs Phoenix as a release behind Caddy, plus Redis and Sidekiq
workers for the crawler. After pulling changes, rebuild and overwrite the
release:

```sh
cd /srv/caio
git pull --ff-only
cd /srv/caio/portal
set -a
source /etc/caio/caio.env
set +a
mix deps.get --only prod
mix compile
mix assets.deploy
mix release --overwrite
sudo systemctl restart caio-portal
```

For crawler migrations in production:

```sh
cd /srv/caio/crawler
set -a
source /etc/caio/caio.env
set +a
RAILS_ENV=production JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3 bundle exec rails db:migrate
```

Rails schema dumping can fail on SQLite virtual FTS tables. The crawler Rails app
should keep schema dumping disabled after migrations.

## Quality Bar

- Run the smallest meaningful verification before finishing. For portal changes,
  prefer `mix test`; for crawler-only Ruby changes, at least run syntax checks
  and any relevant targeted runner/test.
- When changing UI, verify desktop and mobile behavior if practical.
- If a source adapter changes, test one real known job/source example when
  network access is available.
- In final responses, mention what was changed and what was verified. Call out
  anything not run.
