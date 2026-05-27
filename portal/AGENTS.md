# Caio Portal Agent Notes

This is the Phoenix/Elixir public web app for Caio. Also read the root
`AGENTS.md` before editing this app.

## What This App Owns

- Landing page, SEO metadata, social previews, footer/static pages.
- Job search and filters.
- Job detail pages and apply-click tracking.
- Company pages, company stats, company logos, and company sitemap routes.
- Guest unlock, GitHub login, logout, lead/profile capture.
- PostHog browser/server analytics hooks.

Keep the backend behavior simple and server-rendered unless there is a clear
reason to add client complexity.

## Product/UI Direction

The production UI should follow the warm editorial Caio design:

- Paper backgrounds, deep green accents, amber highlights.
- Serif hero/display typography where it adds emotion; practical sans-serif UI
  elsewhere.
- Compact, readable job cards.
- Responsive mobile-first behavior.
- Avoid amateur-looking placeholders. If data is missing, use restrained copy or
  a graceful fallback.

Do not use the prototype files as code to paste into production. Treat `design/`
as reference material.

## Phoenix Conventions

- Templates are HEEx (`.html.heex` or `~H`), never old EEx.
- Use route helpers (`~p`) for internal links.
- Use unique DOM IDs on important forms/buttons where practical.
- Use list syntax for conditional HEEx classes:

  ```elixir
  class={[
    "base-class",
    @active && "active-class"
  ]}
  ```

- Do not use `else if`/`elseif`; use `cond` or `case`.
- Avoid inline `<script>` tags in templates. Put browser behavior in
  `assets/js/app.js`.
- Keep CSS in `assets/css/app.css` and preserve the Tailwind v4 import block if
  present.
- Do not add frontend libraries unless the interaction clearly needs them.

## Data And Performance

- The portal reads the same SQLite database populated by the crawler.
- Prefer indexed queries and precomputed/cached records for company pages and
  counts. Avoid request-time aggregate scans over the full jobs table.
- Company lookups should use canonical slugs/IDs, not `?name=` query params.
- Visible public counts should represent active/usable jobs, not every historical
  row.
- Job descriptions should render source HTML safely. Do not try to reconstruct
  paragraphs or lists in Phoenix if the crawler flattened them; fix ingestion or
  repair the stored description.

## Auth, Leads, And Analytics

- GitHub is the only social login unless the product decision changes.
- Never hardcode OAuth secrets or PostHog keys.
- Guest unlock and job apply flows should record the lead/user before giving
  access or redirecting.
- Apply buttons should preserve the original external job URL unless an explicit
  source-specific correction exists.
- Important product events should be tracked in PostHog, but analytics failures
  must not break user flows.

## Commands

From `portal/`:

```sh
mix compile
mix test
mix format
mix assets.deploy
MIX_ENV=prod mix release --overwrite
```

Use targeted tests when changing one controller/context:

```sh
mix test test/portal_web/controllers/job_controller_test.exs
```

## Release Notes For Agents

- Production deploys require `mix release --overwrite`; compiling assets alone
  is not enough.
- A release eval that needs the Repo should start the app first:

  ```sh
  _build/prod/rel/portal/bin/portal eval 'Application.ensure_all_started(:portal); Portal.Jobs.refresh_companies()'
  ```

- If a page looks stale in production, check the running release and Caddy reload
  before assuming Cloudflare cache.
