# Caio Portal

Phoenix web app for searching the job index produced by the Caio crawler.

The portal is intentionally light: server-rendered Phoenix pages, minimal JavaScript, mobile-first CSS, and direct SQLite reads during local development.

## Features

- Landing page optimized for developer job search.
- Full-text job search across title, company, location, tags, category, and description.
- Filters for role/keyword and location.
- Guest preview of the first 10 jobs.
- Free profile unlock for unlimited results.
- Lead capture with email, optional LinkedIn URL, target role, target location, and consent flag.
- Apply-click tracking in `job_interests` before redirecting to the original job URL.

## Database

In development, `Portal.Repo` points to the crawler database:

```text
../crawler/db/development.sqlite3
```

The portal migration adds:

- `leads`
- `job_interests`
- `job_posts_fts`, an SQLite FTS5 index over the crawler-owned `job_posts` table
- triggers to keep the FTS table current as jobs are inserted or updated

Phoenix uses `portal_schema_migrations` for its migration bookkeeping. This avoids colliding with the Rails crawler's `schema_migrations` table, which has a different schema.

## Setup

```sh
mix setup
mix ecto.migrate
mix phx.server
```

Open:

```text
http://127.0.0.1:4000
```

## Useful Commands

```sh
mix compile
mix format
mix test
mix assets.build
```

## Product Notes

Keep the unlock flow transparent. Users should understand that providing contact details creates a free profile, unlocks unlimited results, and may be used for relevant job-search help when they opt in.
