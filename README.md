# Caio

Caio is an open-source attempt to make job hunting less manual for software
professionals.

The current product is a public tech-job index. That is useful on its own, but it is
not the end goal. The job board is the data layer and acquisition surface for a
larger product: a supervised job-search agent that can continuously find relevant
roles, adapt application material, and help a candidate apply without spending
hours repeating the same search/forms/CV-tweaking loop.

This repo is early, practical, and intentionally boring in places. It favors a
working crawler, simple deploys, server-rendered pages, and observable user flows
over a polished distributed architecture.

Live site: [caio-jobs.com](https://caio-jobs.com)

## Why This Exists

Job boards mostly move the filtering burden onto candidates. The painful part is
not only finding jobs; it is repeatedly deciding whether a role is relevant,
editing the same CV for each posting, filling forms, tracking what happened, and
doing it again tomorrow.

Caio starts with the searchable job corpus because the agent needs one. From there,
the useful product becomes:

- Keep finding fresh jobs that match a candidate profile.
- Explain why a job is or is not a good fit.
- Tailor CV/application material to the role.
- Track applications and outcomes.
- Let the user supervise the workflow instead of manually doing every step.

## What Is In This Repo

Caio is a monorepo with two main apps:

```text
public job sources -> crawler workers -> SQLite job_posts -> Phoenix portal
                                      -> leads + job_interests tracking
```

- `crawler/`: Ruby on Rails plus Sidekiq workers for collecting, normalizing,
  deduplicating, and storing public job postings.
- `portal/`: Phoenix/Elixir web app for the public search experience, profile
  unlock flow, GitHub login, analytics, and apply-click tracking.
- `deploy/`: production deployment scripts and systemd units for a single Google
  Cloud VM.
- `marketing/`: launch copy and social-post drafts.

The current production-friendly setup intentionally uses SQLite. That is not a
claim that SQLite is the final architecture; it is just the fastest path to a
small, understandable system while the product is still being shaped. The natural
next step is Postgres plus separate crawler/web machines.

## Interesting Technical Bits

- Shared SQLite database between Rails ingestion and Phoenix serving.
- SQLite FTS5 index maintained by Phoenix migrations and triggers.
- Rails/Sidekiq crawler split into source fanout, fetch, detail, and write queues.
- Normalization for salary, location, source keys, canonical URLs, and job quality.
- Server-rendered Phoenix UI with minimal JavaScript.
- GitHub OAuth and email unlock flow feeding a simple `leads` table.
- PostHog events for search, unlock, login, job detail views, and apply clicks.
- Single-VM production deployment with systemd, Caddy, Redis, and SQLite backups.

## Current Product Scope

- Public landing page with SEO and social sharing metadata.
- Full-text search across title, company, location, tags, category, and description.
- Guest preview with a free unlock flow.
- GitHub OAuth login.
- Lead/profile capture with email, optional LinkedIn URL, target role, target
  location, and job-help consent.
- Apply-click tracking before redirecting users to the original job source.
- Company stats based on the number of visible open jobs in Caio.
- PostHog analytics hooks for page views, unlocks, GitHub login, and apply clicks.

## What Is Still Rough

- Some crawler paths still reprocess old pages instead of storing complete cursor
  state per paged source.
- Import metrics currently blur inserts and updates in some paths.
- SQLite is acceptable for this stage, but it will need a more deliberate data
  architecture as write volume grows.
- The agent layer is not here yet; today this is the search/indexing foundation.
- Source adapters need ongoing maintenance because public job endpoints change,
  rate-limit, or disappear.

## Repository Layout

```text
.
├── bin/                  # Local orchestration helpers
├── crawler/              # Rails + Sidekiq ingestion system
├── deploy/google-cloud/  # VM bootstrap, Caddy, systemd, backup docs
├── marketing/            # Launch assets and copy
└── portal/               # Phoenix web interface
```

## Requirements

- Ruby with Bundler
- Redis for Sidekiq
- Elixir/Erlang, preferably via `.tool-versions` and `mise`
- SQLite with FTS5 support
- Docker, if you use the local stack helper

## Quick Start

From the repository root:

```sh
cp .env.example .env
bin/run_local_stack --restart
```

This starts:

- Docker Redis as `caio-redis`
- Sidekiq writer/fetch/source workers
- Rails Sidekiq UI at `http://localhost:3001/sidekiq`
- Phoenix portal at `http://localhost:4000`

You can also start pieces independently:

```sh
bin/run_local_stack portal
bin/run_local_stack sidekiq-web
bin/run_local_stack workers
```

If Redis is loading a large persisted queue, increase the startup wait:

```sh
REDIS_READY_TIMEOUT=900 bin/run_local_stack --restart
```

## Manual Development Setup

Run crawler setup:

```sh
cd crawler
bundle install
bin/rails db:migrate
bundle exec sidekiq -C config/sidekiq_sources.yml
```

Run the portal:

```sh
cd portal
mix setup
mix ecto.migrate
mix phx.server
```

Open:

```text
http://127.0.0.1:4000
```

In development, the portal reads the crawler database at:

```text
crawler/db/development.sqlite3
```

## Environment Variables

Use `.env.example` as the local template. Do not commit real secrets.

Common local variables:

```sh
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GITHUB_REDIRECT_URI=http://localhost:4000/auth/github/callback

POSTHOG_ENABLED=false
POSTHOG_PUBLIC_KEY=
POSTHOG_HOST=https://us.i.posthog.com
POSTHOG_SESSION_REPLAY=true
```

Important production variables:

```sh
PHX_HOST=caio-jobs.com
SECRET_KEY_BASE=...
DATABASE_PATH=/var/lib/caio/caio.sqlite3
JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3
GITHUB_REDIRECT_URI=https://caio-jobs.com/auth/github/callback
```

## Useful Commands

Portal:

```sh
cd portal
mix compile
mix test
mix format
mix assets.deploy
MIX_ENV=prod mix release --overwrite
```

Crawler:

```sh
cd crawler
bundle exec rails db:migrate
bundle exec sidekiq -C config/sidekiq_fetch.yml
bundle exec sidekiq -C config/sidekiq_writer.yml
bundle exec sidekiq -C config/sidekiq_sources.yml
```

Queue inspection:

```sh
redis-cli LLEN queue:source_fetchers
redis-cli LLEN queue:linkedin_pages
redis-cli LLEN queue:job_writes
redis-cli ZCARD retry
redis-cli ZCARD dead
```

## Production Deployment

The current deployment path is a single Google Cloud VM running:

- Phoenix release
- Rails/Sidekiq crawler workers
- Redis
- Caddy
- SQLite database on persistent disk

See [deploy/google-cloud/README.md](deploy/google-cloud/README.md) for the full
VM bootstrap, systemd, Caddy, release, and backup workflow.

The short deploy loop after pulling changes is:

```sh
cd /srv/caio/crawler
bundle install
RAILS_ENV=production JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3 bundle exec rails db:migrate

cd /srv/caio/portal
mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod DATABASE_PATH=/var/lib/caio/caio.sqlite3 mix ecto.migrate
MIX_ENV=prod mix release --overwrite

sudo systemctl restart caio-portal caio-sidekiq-writer caio-sidekiq-fetch caio-sidekiq-sources
```

## Data And Git Hygiene

Generated data stays out of git:

- SQLite databases and WAL/SHM files
- Redis dumps
- logs
- Phoenix `_build`, `deps`, and compiled assets
- generated crawler indexes and large crawl artifacts

Commit source code, migrations, small config data, docs, and launch assets.

## Security And Privacy

- Never commit OAuth secrets, PostHog keys, production database files, or backups.
- Keep user contact collection explicit and transparent.
- The analytics wrapper strips sensitive property names such as email, token, and
  secret before sending server-side events.
- Apply clicks are tracked in `job_interests` before redirecting to the original
  job source.

## Roadmap

- Add stateful crawler cursors for every paged source so production resumes from
  known progress instead of reprocessing old pages.
- Split crawler import metrics into inserted vs updated counts.
- Move from SQLite to Postgres when write volume or operational needs require it.
- Add company profile enrichment, including async external reputation data where
  allowed.
- Build the job-agent layer: saved profiles, tailored application material, job
  matching, and supervised automated application workflows.

## License

No license has been added yet. Until a license is present, all rights are reserved
by the repository owner.
