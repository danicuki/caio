# Caio

Caio is a monorepo for a high-volume tech jobs search product. It has two apps:

- `crawler/`: Ruby on Rails plus Sidekiq workers that collect, normalize, deduplicate, and store public job postings.
- `portal/`: Phoenix/Elixir web app that reads the crawler database and gives developers a fast mobile-first search experience.

The current local setup uses SQLite so we can iterate quickly. The crawler and portal intentionally share the same local database at `crawler/db/development.sqlite3`; later this can move to Postgres or another hosted database without changing the product boundary.

## Architecture

```text
public job sources -> crawler workers -> SQLite job_posts -> Phoenix portal
                                      -> leads + job_interests tracking
```

The crawler owns ingestion and data quality. The portal owns search, lead/profile capture, and apply-click tracking. User contact collection must stay transparent: users preview search results, then create a free profile to unlock unlimited results and opt into job-search help.

## Repository Layout

```text
.
├── crawler/   # Rails + Sidekiq ingestion system
└── portal/    # Phoenix web interface
```

## Local Requirements

- Ruby with Bundler
- Redis for Sidekiq
- Elixir/Erlang, preferably via `.tool-versions`
- SQLite

## Quick Start

Start the full local stack after a reboot:

```sh
bin/run_local_stack --restart
```

This starts Docker Redis (`caio-redis`), Sidekiq writer/fetch/source workers, the Rails Sidekiq UI on `http://localhost:3001/sidekiq`, and the Phoenix portal on `http://localhost:4000`.

You can also start pieces independently:

```sh
bin/run_local_stack portal
bin/run_local_stack sidekiq-web
bin/run_local_stack workers
```

If Redis is loading a large persisted queue, the script waits up to 5 minutes by default. Override with:

```sh
REDIS_READY_TIMEOUT=900 bin/run_local_stack --restart
```

Run crawler workers:

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

Open `http://127.0.0.1:4000`.

## Data And Git Hygiene

The repository ignores runtime databases, Sidekiq/Rails logs, Phoenix build output, dependencies, and large generated location indexes. Keep source code, migrations, small seed/config data, and docs in git; keep crawled job data out of git.

## Current Product Scope

- Full-text job search over role, keyword, location, tags, and descriptions.
- Guest preview of the first 10 jobs.
- Free profile unlock for unlimited results.
- Optional LinkedIn URL capture.
- Apply-click tracking through `job_interests`.
- Mobile-first, low-JS Phoenix pages.
